# API Documentation / API Dokümantasyonu

## WebSocket Connection
- **Endpoint:** `ws://<server-ip>:8000/ws/traffic`
- **Description:** Streams real-time network traffic data in JSON format.

## HTTP Endpoints
### 1. System Status
- **Method:** `GET`
- **Path:** `/status`
- **Response:** `{"status": "online", "active_interface": "wlan0"}`

### 2. Traffic History
- **Method:** `GET`
- **Path:** `/history`
- **Description:** Returns the last 50 captured traffic logs.

---

## Türkçe Özet
Mobil uygulama veya web arayüzü, sunucuya yukarıdaki WebSocket adresi üzerinden bağlanarak canlı veri akışını başlatır. Sistem durumu ve geçmiş kayıtlar için standart HTTP GET istekleri kullanılır.