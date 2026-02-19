from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import threading
import asyncio
import json
import uvicorn
import logging
import time
from sniffer import UmaySniffer

# --- Veritabanı Modülleri ---
from core.database import init_db, engine
from sqlmodel import Session, select
from schemas.db_models import Device, TrafficLog

# FastAPI Uygulaması
app = FastAPI()

# Statik Dosyalar
app.mount("/static", StaticFiles(directory="static"), name="static")

# HTML Template Yolu
templates = Jinja2Templates(directory="templates")

# Global Değişkenler
global_sniffer = None
main_event_loop = None  # Thread'lerden ana döngüye erişmek için

# Log temizliği
logging.getLogger("uvicorn.error").setLevel(logging.WARNING)

# --- UYGULAMA BAŞLANGICINDA ANA DÖNGÜYÜ VE VERİTABANINI YAKALA ---
@app.on_event("startup")
async def startup_event():
    global main_event_loop
    main_event_loop = asyncio.get_running_loop()
    
    # 1. Önce PostgreSQL Tablolarını Otomatik Oluştur
    print("[*] Veritabanı motoru ısınıyor (PostgreSQL)...")
    try:
        init_db()
        print("[+] Veritabanı tabloları hazır ve bağlandı!")
    except Exception as e:
        print(f"[!] Veritabanı bağlantı hatası: {e}")
        
    # 2. Tablolar oluştuktan SONRA Sniffer'ı başlat
    print("[*] Sniffer (Ağ Dinleyici) arka planda başlatılıyor...")
    threading.Thread(target=start_sniffer_background, daemon=True).start()

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

# --- SNIFFER CALLBACK (GÜVENLİ İLETİŞİM) ---
def send_to_dashboard(data):
    if main_event_loop and manager.active_connections:
        asyncio.run_coroutine_threadsafe(manager.broadcast(data), main_event_loop)

# --- ARKA PLAN ÇALIŞTIRICI ---
def start_sniffer_background():
    global global_sniffer
    global_sniffer = UmaySniffer(callback=send_to_dashboard)
    global_sniffer.start()

# --- HTTP ENDPOINTS ---
@app.get("/")
async def get_dashboard(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

# --- WEBSOCKET ENDPOINT ---
@app.websocket("/ws/traffic")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    
    if global_sniffer:
        # 1. Ağ Bilgilerini Gönder
        if global_sniffer.network_info.get("public_ip") != "Yükleniyor...":
            await websocket.send_json({"type": "network_info", "data": global_sniffer.network_info})
        
        # 2. Hafızadaki Cihazları Gönder
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

            # --- YENİ: SAYFA YENİLENDİĞİNDE GEÇMİŞ TRAFİĞİ SQL'DEN GETİR ---
            try:
                with Session(engine) as session:
                    # SQL'den son 150 trafiği çek (En yeni en üstte gelir)
                    logs = session.exec(select(TrafficLog).order_by(TrafficLog.id.desc()).limit(150)).all()
                    devices_db = session.exec(select(Device)).all()
                    
                    # Hangi cihaz ID'si hangi MAC adresine ait bul
                    id_to_mac = {d.id: d.mac_address for d in devices_db}
                    
                    # Hangi MAC adresi şu an hangi IP'de oturuyor bul (Canlı hafızadan)
                    mac_to_ip = {v.get('mac'): k for k, v in global_sniffer.discovered_devices.items() if v.get('mac')}
                    
                    # Ekranda kronolojik görünmesi için ters çevirip yolla (Eski -> Yeni)
                    for log in reversed(logs):
                        mac = id_to_mac.get(log.device_id)
                        if mac and mac in mac_to_ip:
                            ip = mac_to_ip[mac]
                            # SQL'deki datetime verisini Unix Timestamp (saniye) formatına çevir
                            ts = log.timestamp.timestamp() if hasattr(log.timestamp, 'timestamp') else time.time()
                            
                            await websocket.send_json({
                                "source": ip,
                                "destination": log.domain,
                                "timestamp": ts
                            })
            except Exception as e:
                print(f"[!] Geçmiş trafik çekilirken hata oluştu: {e}")
            # -------------------------------------------------------------

    try:
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            action = msg.get("action")
            
            if action == "start_scan":
                if global_sniffer:
                    threading.Thread(target=global_sniffer.fast_sweep, daemon=True).start()
            
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
        print(f"WS Hatası: {e}")
        manager.disconnect(websocket)

if __name__ == "__main__":
    print("[*] Umay Sunucusu 8000 portunda çalışıyor. http://localhost:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="error")