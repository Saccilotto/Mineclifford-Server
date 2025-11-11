from fastapi import APIRouter, HTTPException
import sys
from pathlib import Path

# Import do Version Manager existente
sys.path.append(str(Path(__file__).parent.parent.parent.parent))
from version_manager import MinecraftVersionManager
from version_manager.base import ServerType

router = APIRouter(prefix="/api/versions", tags=["versions"])

@router.get("/types")
async def get_server_types():
    """Lista todos os tipos de servidor suportados"""
    return {
        "types": [t.value for t in ServerType],
        "count": len(ServerType)
    }

@router.get("/{server_type}")
async def get_versions(server_type: str, mc_version: str = None, limit: int = 20):
    """Lista versões disponíveis para um tipo de servidor"""
    try:
        manager = MinecraftVersionManager()

        # Converte string para enum
        try:
            server_type_enum = ServerType(server_type.lower())
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid server type. Must be one of: {[t.value for t in ServerType]}"
            )

        # Busca versões
        versions = await manager.list_versions(server_type_enum, mc_version)

        # Limita resultado
        versions = versions[:limit]

        return {
            "server_type": server_type,
            "minecraft_version": mc_version,
            "count": len(versions),
            "versions": [
                {
                    "version": v.version,
                    "minecraft_version": v.minecraft_version,
                    "stable": v.stable,
                    "build_number": v.build_number
                }
                for v in versions
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{server_type}/latest")
async def get_latest_version(server_type: str, mc_version: str = None):
    """Obtém a versão mais recente para um tipo de servidor"""
    try:
        manager = MinecraftVersionManager()

        try:
            server_type_enum = ServerType(server_type.lower())
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid server type. Must be one of: {[t.value for t in ServerType]}"
            )

        latest = await manager.get_latest_version(server_type_enum, mc_version)

        return {
            "server_type": server_type,
            "version": latest.version,
            "minecraft_version": latest.minecraft_version,
            "stable": latest.stable,
            "build_number": latest.build_number
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{server_type}/{version}/download-url")
async def get_download_url(server_type: str, version: str):
    """Obtém URL de download para uma versão específica"""
    try:
        manager = MinecraftVersionManager()

        try:
            server_type_enum = ServerType(server_type.lower())
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid server type. Must be one of: {[t.value for t in ServerType]}"
            )

        url = await manager.get_download_url(server_type_enum, version)

        return {
            "server_type": server_type,
            "version": version,
            "download_url": url
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
