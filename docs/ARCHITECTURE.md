# System Architecture / Sistem Mimarisi

## English
Umay is an asynchronous network traffic monitoring and visualization system consisting of three main layers:

1. **Data Acquisition Layer (Sniffer):**
   - **Technology:** Python & Scapy.
   - **Function:** Captures DNS queries over UDP port 53 by listening to the network interface (NIC).
   - **Process:** It parses captured packets to extract source IP addresses and destination domain names.

2. **Distribution Layer (Backend API):**
   - **Technology:** FastAPI & WebSockets.
   - **Function:** Broadcasts real-time data from the Sniffer to connected mobile/web clients.
   - **Communication:** WebSockets are utilized to ensure low-latency data streaming.

3. **Visualization Layer (Mobile/Web):**
   - **Technology:** Flutter.
   - **Function:** Maps domain information using IP-Location services and visualizes live traffic on a world map.

---

## Türkçe
Umay, üç ana katmandan oluşan asenkron bir ağ trafiği izleme ve görselleştirme sistemidir:

1. **Veri Yakalama Katmanı (Sniffer):**
   - **Teknoloji:** Python & Scapy.
   - **Görev:** Ağ arayüzünü (NIC) dinleyerek UDP 53 portu üzerinden geçen DNS sorgularını yakalar.
   - **İşlem:** Yakalanan paketleri ayrıştırarak kaynak IP ve hedef alan adı (domain) bilgilerini ayıklar.

2. **Dağıtım Katmanı (Backend API):**
   - **Teknoloji:** FastAPI & WebSockets.
   - **Görev:** Sniffer'dan gelen veriyi anlık olarak bağlı istemcilere aktarır.
   - **İletişim:** Veri akışında düşük gecikme sağlamak amacıyla WebSocket protokolü kullanılmıştır.

3. **Görselleştirme Katmanı (Mobil/Web):**
   - **Teknoloji:** Flutter.
   - **Görev:** Gelen alan adı bilgilerini konum servisleri ile eşleştirerek dünya haritası üzerinde anlık trafik çizgileri oluşturur.