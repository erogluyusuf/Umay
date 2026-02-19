from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi import Request
from core.config import settings
import json
import asyncio

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

# Statik dosyaları ve HTML şablonlarını bağlayalım (Dashboard için)
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Aktif WebSocket bağlantılarını tutan liste
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        """Tüm bağlı cihazlara (Mobil/Web) aynı anda veri gönderir."""
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                # Bağlantısı kopanları listeden temizle
                self.active_connections.remove(connection)

manager = ConnectionManager()

# --- ROUTES (Yollar) ---

@app.get("/")
async def get_dashboard(request: Request):
    """Web arayüzünü (Dashboard) döndürür."""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    """Sistemin ayakta olup olmadığını kontrol eder."""
    return {
        "status": "online", 
        "interface": settings.INTERFACE,
        "project": settings.PROJECT_NAME
    }

@app.websocket("/ws/traffic")
async def websocket_endpoint(websocket: WebSocket):
    """Mobil uygulamanın ve Dashboard'un bağlandığı canlı veri kanalı."""
    await manager.connect(websocket)
    try:
        while True:
            # Bağlantıyı canlı tutmak için bekler
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)