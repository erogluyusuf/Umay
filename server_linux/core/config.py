import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Proje Bilgileri
    PROJECT_NAME: str = "Umay"
    VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Ağ Ayarları
    INTERFACE: str = "eth0"
    API_PORT: int = 8000
    
    # Dosya Yolları
    # Base dir projenin ana klasörünü temsil eder
    BASE_DIR: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    LOG_FILE: str = os.path.join(BASE_DIR, "logs/umay.log")
    
    # Pydantic 2.x ayarları: .env dosyasını otomatik oku
    model_config = SettingsConfigDict(
        env_file=".env", 
        env_file_encoding="utf-8",
        extra="ignore" # .env içinde fazladan değişken varsa hata verme
    )

# Singleton Pattern: Ayarları bir kez oluşturup her yerden çağırıyoruz
settings = Settings()