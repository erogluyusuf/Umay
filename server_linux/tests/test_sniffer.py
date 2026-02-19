import sys
import os
import time
from scapy.all import Ether, ARP, sendp

# Üst dizine erişim sağla (sniffer modülünü görebilmek için gerekebilir)
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def spoof_device(ip, mac, description):
    """
    Belirli bir MAC ve IP ile ağa ARP duyurusu yapar.
    Umay Sniffer bu paketleri yakalayıp 'deep_scan' başlatacaktır.
    """
    print(f"[*] {description} taklit ediliyor: {ip} -> {mac}")
    # ARP Op 2: Reply (Cevap) paketidir, sniffer'ı "yeni cihaz" diye uyandırır.
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(op=2, psrc=ip, hwsrc=mac, pdst=ip)
    sendp(pkt, verbose=0)

if __name__ == "__main__":
    print("=== Umay Kimlik Taklit Testi Başlatıldı ===\n")
    
    # Test Senaryoları: Elindeki markalara göre MAC adresleri
    test_cases = [
        ("192.168.1.220", "b8:27:eb:aa:bb:cc", "Raspberry Pi"),
        ("192.168.1.221", "ac:3c:0b:12:34:56", "Apple iPhone"),
        ("192.168.1.222", "64:09:80:11:22:33", "Xiaomi"),
        ("192.168.1.223", "00:0c:29:ff:ee:dd", "VMware (Dell/Intel tabanlı)"),
        ("192.168.1.224", "00:04:f2:99:88:77", "Polycom (Veya listedeki başka bir IP Telefon)")
    ]

    try:
        for ip, mac, desc in test_cases:
            spoof_device(ip, mac, desc)
            time.sleep(1) # Sniffer'ın işlemesi için kısa bir ara
        
        print("\n[+] Tüm sahte paketler gönderildi.")
        print("[!] Şimdi Web Arayüzünü kontrol et: Marka logoları gelmiş mi?")
    except KeyboardInterrupt:
        print("\n[-] Test durduruldu.")