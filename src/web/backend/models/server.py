from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime

class ServerStatus(str, Enum):
    CREATING = "creating"
    RUNNING = "running"
    STOPPED = "stopped"
    ERROR = "error"

class ServerType(str, Enum):
    VANILLA = "vanilla"
    PAPER = "paper"
    SPIGOT = "spigot"
    FORGE = "forge"
    FABRIC = "fabric"

class ServerCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=50)
    server_type: ServerType
    version: str
    memory: str = "2G"
    max_players: int = Field(default=20, ge=1, le=1000)
    gamemode: str = Field(default="survival", pattern="^(survival|creative|adventure|spectator)$")
    difficulty: str = Field(default="normal", pattern="^(peaceful|easy|normal|hard)$")
    provider: str = Field(default="local", pattern="^(aws|azure|local)$")
    region: str = "us-east-1"

class ServerResponse(BaseModel):
    id: str
    name: str
    server_type: ServerType
    version: str
    status: ServerStatus
    ip_address: Optional[str] = None
    port: int = 25565
    container_id: Optional[str] = None
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True
