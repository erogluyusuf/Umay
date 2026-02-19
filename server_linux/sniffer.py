from scapy.all import (
    sniff, DNS, DNSQR, IP, conf, get_working_ifaces, 
    Ether, ARP, srp, send
)
import logging
import time
import requests
import socket
import threading
import csv
import os
import subprocess
import platform
import re
from concurrent.futures import ThreadPoolExecutor

# --- SQLModel ve Veritabanı Modülleri ---
from sqlmodel import Session, select
from sqlalchemy import text # YENİ: Raw SQL sorguları için eklendi
from core.database import engine
from schemas.db_models import Node, Device, TrafficLog
from datetime import datetime

# Loglama ayarları
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- KILL SWITCH CLASS (ARP POISONING) ---
class ArpBlocker(threading.Thread):
    def __init__(self, target_ip, gateway_ip, interface):
        super().__init__()
        self.target_ip = target_ip
        self.gateway_ip = gateway_ip
        self.interface = interface
        self.running = True
        self.daemon = True

    def run(self):
        logger.info(f"[KILL] {self.target_ip} için engelleme başlatıldı.")
        while self.running:
            try:
                send(ARP(op=2, pdst=self.target_ip, psrc=self.gateway_ip, hwdst="ff:ff:ff:ff:ff:ff"), verbose=0, iface=self.interface)
                time.sleep(1) 
            except Exception as e:
                logger.error(f"Kill Hatası: {e}")
                break
    
    def stop(self):
        self.running = False
        logger.info(f"[KILL] {self.target_ip} serbest bırakılıyor...")
        try:
            send(ARP(op=2, pdst=self.target_ip, psrc=self.gateway_ip, hwdst="ff:ff:ff:ff:ff:ff"), count=3, verbose=0, iface=self.interface)
        except: pass

class UmaySniffer:
    def __init__(self, callback=None):
        self.interface = self.detect_active_interface()
        self.callback = callback
        
        # --- VERİTABANI VE HAFIZA ---
        self.db_lock = threading.Lock() # Yarış Durumu (Race Condition) Kilidi
        self.discovered_devices = {}    # UI için Canlı Hafıza
        self.mac_db = {}
        
        self.active_killers = {} 
        self.network_info = { 
            "public_ip": "Yükleniyor...", "isp": "Yükleniyor...",
            "city": "...", "country": "...", "gateway": "..."
        }
        
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.data_dir = os.path.join(self.base_dir, "data")
        
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
        
        self.load_ieee_database()
        self.current_node_id = self.setup_current_node()
        
        threading.Thread(target=self.fetch_network_details, daemon=True).start()

    # --- VERİTABANI İŞLEMLERİ ---
    def setup_current_node(self):
        vpn_ip = os.getenv("EXTERNAL_IP", "127.0.0.1")
        with Session(engine) as session:
            node = session.exec(select(Node).where(Node.vpn_ip == vpn_ip)).first()
            if not node:
                node = Node(name=f"Umay-Node-{vpn_ip[-3:]}", vpn_ip=vpn_ip)
                session.add(node)
                session.commit()
                session.refresh(node)
            return node.id

    def get_or_create_device(self, mac, ip):
        with Session(engine) as session:
            device = session.exec(select(Device).where(Device.mac_address == mac)).first()
            if device:
                return device
            
            with self.db_lock:
                device = session.exec(select(Device).where(Device.mac_address == mac)).first()
                if not device:
                    vendor = self.get_vendor(mac)
                    device_name = self.get_hostname(ip)
                    device = Device(
                        node_id=self.current_node_id,
                        mac_address=mac,
                        device_name=device_name,
                        brand=vendor,
                        is_managed=False
                    )
                    session.add(device)
                    session.commit()
                    session.refresh(device)
                return device

    def save_traffic_log(self, device_id, domain):
        """Domain ismine göre kategori belirler ve SQL'e kaydeder."""
        category = "Genel"
        domain_lower = domain.lower()
        
        # --- BASİT SINIFLANDIRICI (Kategorize Etme) ---
        if any(x in domain_lower for x in ["facebook", "instagram", "twitter", "tiktok", "snapchat", "linkedin"]):
            category = "Sosyal Medya"
        elif any(x in domain_lower for x in ["youtube", "netflix", "spotify", "twitch", "disney", "primevideo"]):
            category = "Medya & Video"
        elif any(x in domain_lower for x in ["google.com", "bing.com", "yahoo.com", "yandex", "duckduckgo"]):
            category = "Arama Motoru"
        elif any(x in domain_lower for x in ["whatsapp", "telegram", "discord", "skype", "zoom"]):
            category = "Mesajlaşma"
        elif any(x in domain_lower for x in ["github", "stackoverflow", "aws", "cloudflare", "digitalocean"]):
            category = "Yazılım / Bulut"
        elif any(x in domain_lower for x in ["binance", "coin", "crypto", "bank", "paypal", "garanti", "ziraat"]):
            category = "Finans & Kripto"
        elif any(x in domain_lower for x in ["ads", "analytics", "tracker", "metric"]):
            category = "Reklam / Takip"

        with Session(engine) as session:
            log = TrafficLog(device_id=device_id, domain=domain, category=category)
            session.add(log)
            session.commit()

    # --- DNS RESOLVER ---
    def dns_resolver(self):
        try:
            dns_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            dns_sock.bind(('0.0.0.0', 53))
            logger.info("[*] Umay DNS Sunucusu 53. portta aktif!")
        except Exception as e:
            logger.error(f"[-] DNS Portu (53) açılamadı!: {e}")
            return

        while True:
            try:
                data, addr = dns_sock.recvfrom(1024)
                dns_pkt = DNS(data)
                if dns_pkt.haslayer(DNSQR):
                    query_name = dns_pkt[DNSQR].qname.decode(errors='ignore').strip('.')
                    client_ip = addr[0]
                    
                    if self.callback:
                        self.callback({
                            "source": client_ip,
                            "destination": query_name,
                            "timestamp": time.time(),
                            "type": "dns_resolved"
                        })

                    forward_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    forward_sock.settimeout(1.5)
                    forward_sock.sendto(data, ('8.8.8.8', 53))
                    try:
                        response, _ = forward_sock.recvfrom(1024)
                        dns_sock.sendto(response, addr)
                    except: pass
                    finally: forward_sock.close()
            except: continue

    # --- YARDIMCI FONKSİYONLAR ---
    def load_ieee_database(self):
        csv_path = os.path.join(self.data_dir, "oui.csv")
        if not os.path.exists(csv_path): return
        try:
            with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f)
                next(reader, None)
                for row in reader:
                    if len(row) > 2: self.mac_db[row[1].strip().upper()] = row[2].strip()
        except: pass

    def fetch_network_details(self):
        try:
            gw = conf.route.route("0.0.0.0")[2]
            self.network_info["gateway"] = gw
            res = requests.get("http://ip-api.com/json/", timeout=5).json()
            self.network_info.update({
                "public_ip": res.get("query", "Bilinmiyor"),
                "isp": res.get("isp", "Bilinmiyor"),
                "city": res.get("city", "Bilinmiyor"),
                "country": res.get("country", "Bilinmiyor")
            })
            self.send_network_info()
        except: pass

    def send_network_info(self):
        if self.callback: self.callback({"type": "network_info", "data": self.network_info})

    def detect_active_interface(self):
        try:
            iface = conf.iface
            if not iface or str(iface) in ["lo", "lo0", "None"]:
                for i in get_working_ifaces():
                    if i.name != "lo" and i.ip: return i.name
            return str(iface)
        except: return "eth0"

    def toggle_kill(self, target_ip, state):
        if state:
            if target_ip in self.active_killers: return 
            gateway = self.network_info.get("gateway")
            killer = ArpBlocker(target_ip, gateway, self.interface)
            self.active_killers[target_ip] = killer
            killer.start()
        else:
            if target_ip in self.active_killers:
                self.active_killers[target_ip].stop()
                del self.active_killers[target_ip]

    def get_real_ping(self, ip):
        try:
            param = '-n' if platform.system().lower() == 'windows' else '-c'
            timeout_p = ['-W', '1'] if platform.system().lower() != 'windows' else ['-w', '1000']
            command = ['ping', param, '1'] + timeout_p + [ip]
            start = time.time()
            result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            end = time.time()
            if result.returncode == 0:
                return round(max(1, (end - start) * 1000 - 5), 2)
            return None
        except: return None

    # --- PORT VE OS TARAMALARI ---
    def get_service_banner(self, ip, port):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1.0)
            s.connect((ip, port))
            if port in [80, 8080, 443]:
                s.send(b"GET / HTTP/1.1\r\nHost: " + ip.encode() + b"\r\n\r\n")
                banner = s.recv(1024).decode(errors='ignore')
                server = re.search(r"Server: (.*)", banner)
                return server.group(1).strip() if server else "Web Sunucusu"
            banner = s.recv(1024).decode(errors='ignore').strip()
            s.close()
            return banner if banner else "Bilinmeyen Servis"
        except: return "Yanıt Yok"

    def scan_ports(self, ip):
        services = {}
        vulns = [] 
        tcp_ports = [21, 22, 23, 80, 443, 445, 3389, 8080]
        for port in tcp_ports:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(0.2)
                if s.connect_ex((ip, port)) == 0:
                    banner = self.get_service_banner(ip, port)
                    services[str(port)] = banner
                    if port == 21: vulns.append("FTP: Şifresiz Veri Aktarımı")
                    if port == 23: vulns.append("Telnet: Güvensiz Protokol")
                    if port == 445: vulns.append("SMB: Kritik Port (Exploit Riski)")
                s.close()
            except: continue
        return services, vulns

    def get_vendor(self, mac):
        return self.mac_db.get(mac.replace(":", "").upper()[:6], "Bilinmeyen Üretici")

    def get_hostname(self, ip):
        try:
            socket.setdefaulttimeout(0.2)
            return socket.gethostbyaddr(ip)[0]
        except: return "İsimsiz Cihaz"

    def guess_os(self, ttl):
        if not ttl: return "Bilinmiyor"
        return "Linux / Android" if ttl <= 64 else "Windows" if ttl <= 128 else "Network Device"

    # --- AĞ TARAMA (DISCOVERY) ---
    def deep_scan(self, ip, mac, ttl=None):
        vendor = self.get_vendor(mac)
        hostname = self.get_hostname(ip)
        service_data, vulns = self.scan_ports(ip)
        os_guess = self.guess_os(ttl)
        
        # 1. Canlı Hafızayı Güncelle (Arayüz İçin)
        self.discovered_devices[ip] = {
            "vendor": vendor, "mac": mac, "hostname": hostname,
            "os": os_guess, "services": service_data, "ports": list(service_data.keys()),
            "vulns": vulns, "last_seen": time.time()
        }
        
        # 2. Kalıcı SQL Kaydı
        def db_update_task():
            self.get_or_create_device(mac, ip)
        threading.Thread(target=db_update_task, daemon=True).start()
        
        # 3. WebSocket ile UI'a Gönder
        if self.callback:
            self.callback({
                "source": ip, "mac": mac, "destination": "Tarama Bitti", 
                "vendor": vendor, "hostname": hostname, "ports": list(service_data.keys()), 
                "os": os_guess, "services": service_data, "vulns": vulns,
                "timestamp": time.time()
            })

    def fast_sweep(self):
        gw = self.network_info.get("gateway", "192.168.1.1")
        base = ".".join(gw.split(".")[:3])
        active_ips = []

        logger.info("[*] Tarama ve Temizlik Başlatılıyor...")

        def scan_and_track(ip):
            if self.scan_single_target(ip):
                active_ips.append(ip)

        with ThreadPoolExecutor(max_workers=50) as ex:
            list(ex.map(scan_and_track, [f"{base}.{i}" for i in range(1, 255)]))

        local_ip = self.get_local_ip()
        active_ips.extend([local_ip, gw])

        offline_devices = [ip for ip in self.discovered_devices.keys() if ip not in active_ips]

        if offline_devices:
            logger.info(f"[-] {len(offline_devices)} adet offline cihaz UI'dan temizleniyor...")
            for ip in offline_devices:
                del self.discovered_devices[ip]
                if self.callback:
                    self.callback({"source": ip, "type": "device_offline"})
        else:
            logger.info("[+] Tüm kayıtlı cihazlar hala aktif.")

    def scan_single_target(self, ip):
        try:
            pkt = Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(pdst=ip)
            res, _ = srp(pkt, timeout=0.8, verbose=0, iface=self.interface)
            for _, r in res:
                if r.psrc not in self.discovered_devices:
                    self.deep_scan(r.psrc, r.hwsrc)
                return True 
            return False 
        except: return False

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except: return "127.0.0.1"

    # --- TRAFİK İZLEME VE FİLTRELEME (SNIFF) ---
    def process_packet(self, packet):
        if packet.haslayer(IP) and packet[IP].src.startswith("192.168."):
            src_ip = packet[IP].src
            dst_ip = packet[IP].dst
            
            src_mac = packet[Ether].src if packet.haslayer(Ether) else "00:00:00:00:00:00"

            if src_ip not in self.discovered_devices:
                threading.Thread(target=self.deep_scan, args=(src_ip, src_mac, packet[IP].ttl), daemon=True).start()
            else:
                dest = dst_ip
                if packet.haslayer(DNSQR): 
                    dest = packet[DNSQR].qname.decode(errors='ignore').strip('.')

                # --- AKILLI WEB TRAFİĞİ FİLTRESİ ---
                def is_real_web_traffic(domain):
                    domain = domain.lower()
                    
                    # 1. Kural: Yerel ağ adreslerini yoksay
                    if domain.startswith("192.168.") or domain.endswith(".local") or domain.endswith(".arpa"):
                        return False
                        
                    # 2. Kural: Sadece IP adresi ise yoksay
                    if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", domain):
                        return False
                        
                    # 3. Kural: Çok parçalı domainleri yoksay (Maksimum 3 nokta)
                    if len(domain.split('.')) > 3:
                        return False
                        
                    # 4. Kural: Dev bulut, telemetri ve altyapı servislerini yoksay
                    infrastructure_noise = [
                        "azure", "cloudapp", "amazonaws", "fastly", "gstatic", 
                        "googleapis", "akamai", "cloudflare", "microsoft.com", 
                        "apple.com", "gvt1.com", "events", "metrics", "telemetry",
                        "mozilla.org", "windows.com", "icloud.com"
                    ]
                    if any(noise in domain for noise in infrastructure_noise):
                        return False
                        
                    return True # Testleri geçtiyse gerçek bir web sitesidir

                # Eğer trafik filtreyi geçtiyse işle
                if is_real_web_traffic(dest):
                    
                    # WWW ön ekini temizle
                    if dest.startswith("www."):
                        dest = dest[4:]

                    def db_task():
                        device = self.get_or_create_device(src_mac, src_ip)
                        self.save_traffic_log(device.id, dest)
                    
                    threading.Thread(target=db_task, daemon=True).start()

                    if self.callback:
                        self.callback({"source": src_ip, "destination": dest, "timestamp": time.time()})

    def start(self):
        # --- YENİ: OTOMATİK VERİTABANI TEMİZLİĞİ (GÜNDE 1 KEZ ÇALIŞIR) ---
        def auto_cleanup():
            while True:
                try:
                    with Session(engine) as session:
                        # 24 saatten eski logları SQL'den kalıcı olarak sil
                        session.exec(text("DELETE FROM trafficlog WHERE timestamp < NOW() - INTERVAL '1 day'"))
                        session.commit()
                        logger.info("[+] 24 saatten eski trafik logları temizlendi (Disk tasarrufu).")
                except Exception as e:
                    pass
                time.sleep(86400) # 86400 saniye = 24 saatte bir tekrarla
        
        threading.Thread(target=auto_cleanup, daemon=True).start()
        # -----------------------------------------------------------------

        # 1. Eski cihazları bas (Eğer UI yenilenirse)
        if self.callback:
            for ip, d in self.discovered_devices.items():
                self.callback({**d, "source": ip, "destination": "Tarama Bitti", "timestamp": time.time()})
        
        # 2. DNS
        if os.getenv("UMAY_ENABLE_DNS", "false").lower() == "true":
            logger.info("[*] DNS Modu Aktif: 53. Port dinleniyor...")
            threading.Thread(target=self.dns_resolver, daemon=True).start()

        # 3. Otomatik Tarama
        logger.info("[*] Başlangıç taraması (1-254) başlatılıyor...")
        threading.Thread(target=self.fast_sweep, daemon=True).start()

        # 4. Sniffing
        logger.info(f"[*] Umay Dinleme Modunda: {self.interface}")
        sniff(iface=self.interface, prn=self.process_packet, store=0)