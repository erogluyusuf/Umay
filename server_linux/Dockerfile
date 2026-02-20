# 1. Hafif Python imajı (Debian tabanlı)
FROM python:3.10-slim

# 2. Python loglarının anlık görünmesi için
ENV PYTHONUNBUFFERED=1

# 3. Sistem bağımlılıklarını kur
# - wireguard-tools: wg genkey komutu için ŞART!
RUN apt-get update && apt-get install -y \
    libpcap-dev \
    gcc \
    iputils-ping \
    net-tools \
    iproute2 \
    wireguard-tools \
    && rm -rf /var/lib/apt/lists/*

# 4. Çalışma dizinini ayarla
WORKDIR /app

# 5. Gereksinimleri yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 6. Uygulama kodunu kopyala
COPY . .

# 7. Uygulamayı başlat
CMD ["python", "-u", "main.py"]