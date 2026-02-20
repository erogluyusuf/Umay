#!/bin/bash

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- CLEANUP FONKSİYONU ---
cleanup() {
    echo -e "\n${RED}[!] Umay kapatılıyor...${NC}"
    
    if [ -f /etc/resolv.conf.backup_umay ]; then
        echo -e "${YELLOW}[*] DNS ayarları geri yükleniyor...${NC}"
        mv /etc/resolv.conf.backup_umay /etc/resolv.conf
        echo -e "${YELLOW}[*] systemd-resolved uyandırılıyor...${NC}"
        systemctl start systemd-resolved systemd-resolved.socket systemd-resolved-varlink.socket > /dev/null 2>&1
        echo -e "${GREEN}[OK] İnternet geri geldi.${NC}"
    else
        echo -e "${GREEN}[OK] Güle güle!${NC}"
    fi
}
trap cleanup EXIT

# --- AVAHI/mDNS KONTROL VE KURULUM FONKSİYONU ---
setup_avahi() {
    echo -e "${YELLOW}[*] Avahi/mDNS servisleri kontrol ediliyor...${NC}"
    
    # Avahi yüklü mü? (Fedora/RHEL tabanlı sistemler için dnf kontrolü)
    if ! command -v avahi-daemon &> /dev/null; then
        echo -e "${YELLOW}[!] Avahi yüklü değil. Kurulum başlatılıyor...${NC}"
        dnf install -y avahi avahi-tools > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${RED}[HATA] Avahi kurulamadı. Lütfen internetinizi kontrol edin.${NC}"
        fi
    fi

    # mDNS ismini ayarla (api.umaysentinel.local olacak)
    echo -e "${GREEN}[OK] Ağ ismi yapılandırılıyor: api.umaysentinel.local${NC}"
    hostnamectl set-hostname api.umaysentinel

    # Servisi etkinleştir ve başlat
    systemctl enable --now avahi-daemon > /dev/null 2>&1
    
    # Güvenlik duvarından mDNS trafiğine (Port 5353) izin ver
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=mdns > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
    fi
}

echo -e "${GREEN}--- Umay Başlatıcı (v3.1 - Global & SQL & mDNS) ---${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[HATA] Root yetkisi şart!${NC} (sudo ./baslat.sh)"
  exit 1
fi

# --- KULLANICIYA SOR ---
echo -e "${BLUE}Nasıl başlatmak istersiniz?${NC}"
echo -e "1) ${GREEN}Sadece İzleme (Passive):${NC} Port 53'e dokunma."
echo -e "2) ${RED}DNS Sunucusu (Active):${NC} Yerel ağı kendi üzerinden geçir."
echo -e "3) ${YELLOW}Uzaktan Erişim (Remote):${NC} VPN & mDNS (api.umaysentinel.local) Aktif.${NC}"
read -p "Seçiminiz (1/2/3): " SECIM

# --- DOCKER KOMUTUNU BELİRLE ---
if docker compose version &> /dev/null; then CMD="docker compose"; else CMD="docker-compose"; fi

# --- VARSAYILAN DEĞİŞKENLER ---
export UMAY_ENABLE_DNS="false"
export UMAY_REMOTE_MODE="false"
PROFILE_ARG="" 

# Port 53 ve Ağ Operasyonları
if [ "$SECIM" != "1" ]; then
    echo -e "${YELLOW}[*] Port 53 temizliği yapılıyor...${NC}"
    export UMAY_ENABLE_DNS="true"

    systemctl stop systemd-resolved.socket systemd-resolved-varlink.socket > /dev/null 2>&1
    systemctl stop systemd-resolved > /dev/null 2>&1

    PID_53=$(ss -tunlp | grep ":53 " | awk '{print $7}' | cut -d'=' -f2 | cut -d',' -f1 | head -n 1)
    
    if [ -z "$PID_53" ]; then
        fuser -k 53/tcp 53/udp > /dev/null 2>&1
    else
        echo -e "${YELLOW}[*] Port 53'ü işgal eden süreç ($PID_53) sonlandırılıyor...${NC}"
        kill -9 $PID_53 > /dev/null 2>&1
    fi

    if ss -tunlp | grep -q ":53 "; then
        echo -e "${RED}[HATA] Port 53 hala temizlenemedi! Manuel müdahale gerek.${NC}"
        ss -tunlp | grep ":53 "
        exit 1
    else
        echo -e "${GREEN}[OK] Port 53 Umay için hazır.${NC}"
    fi

    if [ ! -f /etc/resolv.conf.backup_umay ]; then
        cp /etc/resolv.conf /etc/resolv.conf.backup_umay
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
    fi

    if [ "$SECIM" == "3" ]; then
        export UMAY_REMOTE_MODE="true"
        PROFILE_ARG="--profile vpn_aktif" 
        
        # --- AVAHI BURADA TETİKLENİR ---
        setup_avahi
        
        echo -e "${YELLOW}[*] Dış IP adresi otomatik tespit ediliyor...${NC}"
        AUTO_IP=$(curl -s ifconfig.me)
        
        if [ -z "$AUTO_IP" ]; then
            echo -e "${RED}[UYARI] Dış IP tespit edilemedi!${NC}"
            read -p "Lütfen manuel girin: " EXTERNAL_IP
        else
            echo -e "${GREEN}[OK] Tespit edilen Dış IP: $AUTO_IP${NC}"
            EXTERNAL_IP=$AUTO_IP
        fi
        export EXTERNAL_IP=$EXTERNAL_IP
    fi
else
    echo -e "${GREEN}[OK] Pasif Mod. Sistem DNS ayarlarına dokunulmuyor.${NC}"
fi

# --- KLASÖR DÜZELTME ---
if [ -d "server_linux/assets" ] && [ ! -d "server_linux/static/assets" ]; then
    mv server_linux/assets server_linux/static/ 2>/dev/null
fi

# --- 4. AKILLI TARAYICI BAŞLATICISI ---
echo -e "${BLUE}[INFO] Sistem arka planda ayağa kaldırılıyor. Hazır olduğunda tarayıcı otomatik açılacak...${NC}"

open_browser() {
    for i in {1..120}; do
        if curl -s -f http://localhost:8000 > /dev/null 2>&1; then
            echo -e "\n${GREEN}[+] Sunucu hazır! Tarayıcı açılıyor...${NC}"
            if [ -n "$SUDO_USER" ]; then
                USER_ID=$(id -u "$SUDO_USER")
                sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" xdg-open http://localhost:8000 > /dev/null 2>&1
            else
                xdg-open http://localhost:8000 > /dev/null 2>&1
            fi
            break
        fi
        sleep 1
    done
}

open_browser &

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   PANEL ADRESİ: http://localhost:8000  ${NC}"
if [ "$SECIM" == "3" ]; then
echo -e "${GREEN}   mDNS API: http://api.umaysentinel.local:8000 ${NC}"
fi
echo -e "${GREEN}========================================${NC}\n"

# --- BAŞLAT ---
echo -e "${GREEN}--- Umay Başlatılıyor... ---${NC}"
$CMD $PROFILE_ARG up --build