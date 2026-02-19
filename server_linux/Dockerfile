# 1. Hafif Python imajı (Debian tabanlı)
FROM python:3.10-slim

# 2. Python loglarının anlık görünmesi için (Tamponlamayı kapatır)
ENV PYTHONUNBUFFERED=1

# 3. Sistem bağımlılıklarını kur
# - libpcap-dev: Scapy paket yakalama için şart.
# - gcc: Bazı Python kütüphanelerini derlemek için.
# - iputils-ping: "OFFLINE" sorununu çözen paket (ping komutu).
# - net-tools & iproute2: Ağ analizi ve hata ayıklama için (arp, ifconfig, ip vb.).
RUN apt-get update && apt-get install -y \
    libpcap-dev \
    gcc \
    iputils-ping \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 4. Çalışma dizinini ayarla
WORKDIR /app

# 5. Önce gereksinimleri kopyala ve yükle (Cache optimizasyonu için)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 6. Kalan tüm uygulama kodunu kopyala
COPY . .

# 7. Uygulamayı başlat
# "-u" parametresi print() çıktılarının terminale anında düşmesini sağlar.
CMD ["python", "-u", "main.py"]