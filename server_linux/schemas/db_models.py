from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional
from datetime import datetime

# Ana Düğüm (Örn: Erzurum, İstanbul Şubeleri)
class Node(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True) 
    vpn_ip: str = Field(unique=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    devices: List["Device"] = Relationship(back_populates="node")

# Bağlı Cihazlar (Ana cihaz + Altındaki misafirler)
class Device(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    node_id: int = Field(foreign_key="node.id")
    mac_address: str = Field(unique=True, index=True)
    device_name: Optional[str] = None
    brand: str = Field(default="generic")
    is_managed: bool = Field(default=False)
    node: Node = Relationship(back_populates="devices")
    logs: List["TrafficLog"] = Relationship(back_populates="device")

# Trafik Verisi (Sınıflandırılmış)
class TrafficLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: int = Field(foreign_key="device.id")
    domain: str
    category: str = Field(default="uncategorized") 
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    device: Device = Relationship(back_populates="logs")