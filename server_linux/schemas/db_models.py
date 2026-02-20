from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional
from datetime import datetime

# --- 1. KULLANICI TABLOSU (Google Login İçin) ---
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    google_id: str = Field(unique=True, index=True) # Google'dan gelen eşsiz ID
    email: str = Field(unique=True, index=True)
    full_name: str
    picture: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Kullanıcının sahip olduğu cihazlar
    owned_devices: List["Device"] = Relationship(back_populates="owner")

# --- 2. ANA DÜĞÜM (Örn: Erzurum, İstanbul Şubeleri) ---
class Node(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True) 
    vpn_ip: str = Field(unique=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    devices: List["Device"] = Relationship(back_populates="node")

# --- 3. BAĞLI CİHAZLAR (Hiyerarşik ve Sahipli) ---
class Device(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    
    # Hangi Düğüme (Node) Bağlı?
    node_id: int = Field(foreign_key="node.id")
    
    # Hangi Kullanıcıya (User) Ait? (Opsiyonel: Sahipsiz misafir cihazlar olabilir)
    user_id: Optional[int] = Field(default=None, foreign_key="user.id")
    
    # Hangi Cihazın Altında? (Gateway/Linux Server mantığı için)
    parent_device_id: Optional[int] = Field(default=None, foreign_key="device.id")
    
    mac_address: str = Field(unique=True, index=True)
    device_name: Optional[str] = None
    brand: str = Field(default="generic")
    is_managed: bool = Field(default=False)
    
    # İlişkiler (Relationships)
    node: Node = Relationship(back_populates="devices")
    owner: Optional[User] = Relationship(back_populates="owned_devices")
    logs: List["TrafficLog"] = Relationship(back_populates="device")
    
    # Kendi altındaki cihazları bulmak için (Self-Referential)
    sub_devices: List["Device"] = Relationship(
        back_populates="parent_device",
        sa_relationship_kwargs={"remote_side": "Device.parent_device_id"}
    )
    parent_device: Optional["Device"] = Relationship(
        back_populates="sub_devices",
        sa_relationship_kwargs={"remote_side": "Device.id"}
    )

# --- 4. TRAFİK VERİSİ (Sınıflandırılmış) ---
class TrafficLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: int = Field(foreign_key="device.id")
    
    # Eğer NAT/Gateway arkasından geliyorsa, cihazın yerel IP'sini buraya basabiliriz
    local_ip: Optional[str] = None 
    
    domain: str
    category: str = Field(default="Genel") 
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    device: Device = Relationship(back_populates="logs")