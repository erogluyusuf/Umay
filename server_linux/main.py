import os
import subprocess
import traceback  # Hataları detaylı görmek için eklendi
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import threading
import asyncio
import json
import uvicorn
import logging
import time
import socket # Port taraması için eklendi
from contextlib import asynccontextmanager # Startup hatasını çözen yeni kütüphane
from sniffer import UmaySniffer

# --- Veritabanı Modülleri ---
from core.database import init_db, engine
from sqlmodel import Session, select
from schemas.db_models import Device, TrafficLog

# --- Pydantic Modelleri ---
class RegisterDevice(BaseModel):
    email: str
    device_name: str

class RadarIntel(BaseModel):
    agent_ip: str
    discovered_ips: list[str]

# Global Değişkenler
global_sniffer = None
main_event_loop = None

# Log temizliği (Info seviyesini açıyoruz ki istekleri görelim)
logging.getLogger("uvicorn.access").setLevel(logging.INFO)

# --- YENİ MİMARİ: UYGULAMA BAŞLANGICI VE BİTİŞİ ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    global main_event_loop
    main_event_loop = asyncio.get_running_loop()
    
    print("[*] Veritabanı motoru ısınıyor (PostgreSQL)...")
    try:
        init_db()
        print("[+] Veritabanı tabloları hazır ve bağlandı!")
    except Exception as e:
        print(f"[!] Veritabanı bağlantı hatası: {e}")
        
    print("[*] Sniffer (Ağ Dinleyici) arka planda başlatılıyor...")
    threading.Thread(target=start_sniffer_background, daemon=True).start()
    
    yield # Uygulama burada çalışır

# FastAPI Uygulaması
app = FastAPI(lifespan=lifespan)

# Statik Dosyalar ve Template'ler
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")


# --- MOBİL KAYIT ENDPOINT'İ (AKILLI KAYIT & GÜNCELLEME) ---
@app.post("/api/v1/register-device")
async def register_device(data: RegisterDevice):
    try:
        print(f"\n{'='*40}")
        print(f"[*] MOBİLDEN İSTEK GELDİ! Email: {data.email}")
        
        # 1. WireGuard Anahtarlarını Üret
        print("[*] WireGuard anahtarları üretiliyor...")
        priv_key = subprocess.getoutput("wg genkey")
        if "not found" in priv_key:
            raise Exception("wg komutu Docker içinde bulunamadı!")
        print("[+] Anahtar üretildi.")

        # 2. Şablonu oku
        template_path = "vpn_config/templates/peer.conf"
        client_config = ""
        
        if not os.path.exists(template_path):
            print(f"[-] UYARI: {template_path} bulunamadı! (Docker klasör erişimi yok)")
            print("[*] Yedek (Fallback) WireGuard konfigürasyonu oluşturuluyor...")
            client_config = f"""[Interface]
PrivateKey = {priv_key}
Address = 10.13.13.5/32
DNS = 127.0.0.1

[Peer]
PublicKey = LUTFEN_SUNUCU_PUBLIC_KEY_GIRIN
Endpoint = api.umaysentinel.local:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
"""
        else:
            with open(template_path, 'r') as f:
                template_content = f.read()
            client_config = template_content.replace("${PRIVATE_KEY}", priv_key)
            client_config = client_config.replace("${CLIENT_IP}", "10.13.13.5/32") 
            print("[+] VPN Şablonu başarıyla dolduruldu.")

        # 3. Cihazı SQLModel üzerinden veritabanına işle
        print("[*] Veritabanı kontrol ediliyor...")
        with Session(engine) as session:
            mac_id = f"VPN-{data.email[:8]}"
            
            existing_device = session.exec(select(Device).where(Device.mac_address == mac_id)).first()
            
            if existing_device:
                print(f"[+] Cihaz zaten kayıtlı! (ID: {existing_device.id}). Güncelleniyor...")
                existing_device.device_name = data.device_name
                session.add(existing_device)
            else:
                print("[*] Yeni cihaz bulunamadı, sisteme ekleniyor...")
                new_device = Device(
                    node_id=1,
                    device_name=data.device_name,
                    mac_address=mac_id,
                    brand="Mobile VPN",
                    is_managed=True
                )
                session.add(new_device)
                
            session.commit()
            
        print("[+] Veritabanı işlemi BAŞARILI!")
        print(f"{'='*40}\n")

        return {"status": "success", "config": client_config}
    
    except Exception as e:
        print("\n" + "!"*50)
        print(f"[!!!] SUNUCU ÇÖKTÜ (500 HATASI): {str(e)}")
        traceback.print_exc() 
        print("!"*50 + "\n")
        raise HTTPException(status_code=500, detail=str(e))

# --- YENİ EKLENEN: LOCAL RADAR İSTİHBARAT KABUL NOKTASI ---
@app.post("/api/v1/radar-intel")
async def receive_radar_intel(data: RadarIntel):
    print(f"\n[+] SAHA AJANINDAN İSTİHBARAT GELDİ!")
    print(f"[*] Ajan IP: {data.agent_ip}")
    print(f"[*] Bulunan Cihazlar: {len(data.discovered_ips)} adet IP")
    
    try:
        with Session(engine) as session:
            for ip in data.discovered_ips:
                # Android MAC adreslerini gizlediği için geçici bir MAC üretiyoruz
                dummy_mac = f"RADAR-{ip.replace('.', '-')}"
                
                # Bu IP daha önce bu ağda bulunmuş mu kontrol et
                existing = session.exec(select(Device).where(Device.mac_address == dummy_mac)).first()
                if not existing:
                    new_device = Device(
                        node_id=1,
                        device_name=f"Field Target ({ip})",
                        mac_address=dummy_mac,
                        brand="Unknown (Radar)",
                        is_managed=False
                    )
                    session.add(new_device)
            session.commit()
            
        print("[+] Saha istihbaratı veritabanına başarıyla kaydedildi!\n")
        return {"status": "intel_received", "count": len(data.discovered_ips)}
    except Exception as e:
        print(f"[-] İstihbarat kaydedilirken hata oluştu: {str(e)}")
        raise HTTPException(status_code=500, detail="Database Error")

# --- WEBSOCKET YÖNETİCİSİ ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, data: dict):
        if not self.active_connections: return
        message = json.dumps(data)
        to_remove = []
        for connection in self.active_connections:
            try:
                if connection.client_state.name == "CONNECTED":
                    await connection.send_text(message)
                else:
                    to_remove.append(connection)
            except:
                to_remove.append(connection)
        for conn in to_remove:
            self.disconnect(conn)

manager = ConnectionManager()

def send_to_dashboard(data):
    if main_event_loop and manager.active_connections:
        asyncio.run_coroutine_threadsafe(manager.broadcast(data), main_event_loop)

def start_sniffer_background():
    global global_sniffer
    global_sniffer = UmaySniffer(callback=send_to_dashboard)
    global_sniffer.start()

# --- HTTP VE WEBSOCKET ENDPOINTLERİ ---
@app.get("/")
async def get_dashboard(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.websocket("/ws/traffic")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    if global_sniffer:
        if global_sniffer.network_info.get("public_ip") != "Yükleniyor...":
            await websocket.send_json({"type": "network_info", "data": global_sniffer.network_info})
        
        if hasattr(global_sniffer, 'discovered_devices') and global_sniffer.discovered_devices:
            for ip, dev in global_sniffer.discovered_devices.items():
                await websocket.send_json({
                    "source": ip,
                    "mac": dev.get('mac'),
                    "destination": "Tarama Bitti",
                    "vendor": dev.get('vendor'),
                    "hostname": dev.get('hostname'),
                    "ports": dev.get('ports', []),
                    "services": dev.get('services', {}),
                    "vulns": dev.get('vulns', []),
                    "os": dev.get('os'),
                    "timestamp": dev.get('last_seen', 0)
                })

            try:
                with Session(engine) as session:
                    logs = session.exec(select(TrafficLog).order_by(TrafficLog.id.desc()).limit(150)).all()
                    devices_db = session.exec(select(Device)).all()
                    id_to_mac = {d.id: d.mac_address for d in devices_db}
                    mac_to_ip = {v.get('mac'): k for k, v in global_sniffer.discovered_devices.items() if v.get('mac')}
                    
                    for log in reversed(logs):
                        mac = id_to_mac.get(log.device_id)
                        if mac and mac in mac_to_ip:
                            ip = mac_to_ip[mac]
                            ts = log.timestamp.timestamp() if hasattr(log.timestamp, 'timestamp') else time.time()
                            await websocket.send_json({
                                "source": ip,
                                "destination": log.domain,
                                "timestamp": ts
                            })
            except Exception as e:
                print(f"[!] Geçmiş trafik çekilirken hata: {e}")

    try:
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            action = msg.get("action")
            
            # YENİ EKLENEN GERÇEK PORT TARAMA FONKSİYONU
            if action == "start_scan":
                target_ip = msg.get("ip")
                if target_ip:
                    print(f"[*] Port taraması başlatıldı: {target_ip}")
                    def scan_task(ip, ws):
                        try:
                            open_ports = []
                            # En çok kullanılan kritik portlar
                            common_ports = [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1723, 3306, 3389, 5900, 8000, 8080, 8443]
                            
                            for port in common_ports:
                                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                                sock.settimeout(0.2) # Hızlı tarama için 0.2 saniye bekleme süresi
                                result = sock.connect_ex((ip, port))
                                if result == 0:
                                    open_ports.append(port)
                                sock.close()
                            
                            print(f"[+] Tarama Bitti {ip} -> Açık Portlar: {open_ports}")
                            # Sonucu Flutter'a Geri Gönder
                            if main_event_loop:
                                payload = {
                                    "type": "scan_result", 
                                    "ip": ip, 
                                    "ports": open_ports
                                }
                                asyncio.run_coroutine_threadsafe(ws.send_json(payload), main_event_loop)
                        except Exception as e:
                            print(f"[-] Tarama hatası: {e}")
                            
                    # Taramayı arka planda başlat ki sunucu kilitlenmesin
                    threading.Thread(target=scan_task, args=(target_ip, websocket), daemon=True).start()
            
            elif action == "get_ping":
                target_ip = msg.get("ip")
                if target_ip and global_sniffer:
                    def ping_task(ip, ws):
                        try:
                            val = global_sniffer.get_real_ping(ip)
                            if main_event_loop:
                                payload = {"type": "ping_result", "ip": ip, "value": val}
                                asyncio.run_coroutine_threadsafe(ws.send_json(payload), main_event_loop)
                        except: pass
                    threading.Thread(target=ping_task, args=(target_ip, websocket), daemon=True).start()
            
            elif action == "toggle_kill":
                target_ip = msg.get("ip")
                state = msg.get("state")
                if target_ip and global_sniffer:
                    global_sniffer.toggle_kill(target_ip, state)

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        manager.disconnect(websocket)

def get_local_ip():
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

if __name__ == "__main__":
    local_ip = get_local_ip()
    print(f"\n{'-'*50}")
    print(f"[*] Umay Sunucusu 8000 portunda çalışıyor.")
    print(f"[*] Panel: http://localhost:8000")
    print(f"[*] Mobil API: http://{local_ip}:8000")
    print(f"{'-'*50}\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")