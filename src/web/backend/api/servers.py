from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from typing import List
import uuid
import json
from datetime import datetime

from web.backend.models.server import ServerCreate, ServerResponse, ServerStatus
from web.backend.database import get_db

router = APIRouter(prefix="/api/servers", tags=["servers"])

@router.get("/", response_model=List[ServerResponse])
async def list_servers():
    """Lista todos os servidores"""
    db = await get_db()

    cursor = await db.execute("""
        SELECT id, name, server_type, version, status,
               ip_address, port, created_at, updated_at
        FROM servers
        ORDER BY created_at DESC
    """)

    rows = await cursor.fetchall()

    return [
        ServerResponse(
            id=row['id'],
            name=row['name'],
            server_type=row['server_type'],
            version=row['version'],
            status=row['status'],
            ip_address=row['ip_address'],
            port=row['port'],
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )
        for row in rows
    ]

@router.post("/", response_model=ServerResponse, status_code=201)
async def create_server(server: ServerCreate):
    """Cria um novo servidor"""
    db = await get_db()

    # Gera ID único
    server_id = str(uuid.uuid4())

    # Converte config para JSON
    config_json = json.dumps(server.model_dump())

    try:
        await db.execute("""
            INSERT INTO servers
            (id, name, server_type, version, status, config, port)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            server_id,
            server.name,
            server.server_type.value,
            server.version,
            ServerStatus.CREATING.value,
            config_json,
            25565
        ))

        await db.commit()

        # TODO: Iniciar deployment assíncrono aqui
        # asyncio.create_task(deploy_server(server_id, server))

        return ServerResponse(
            id=server_id,
            name=server.name,
            server_type=server.server_type,
            version=server.version,
            status=ServerStatus.CREATING,
            port=25565,
            created_at=datetime.now().isoformat(),
            updated_at=datetime.now().isoformat()
        )

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{server_id}", response_model=ServerResponse)
async def get_server(server_id: str):
    """Obtém detalhes de um servidor específico"""
    db = await get_db()

    cursor = await db.execute("""
        SELECT id, name, server_type, version, status,
               ip_address, port, created_at, updated_at
        FROM servers
        WHERE id = ?
    """, (server_id,))

    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    return ServerResponse(
        id=row['id'],
        name=row['name'],
        server_type=row['server_type'],
        version=row['version'],
        status=row['status'],
        ip_address=row['ip_address'],
        port=row['port'],
        created_at=row['created_at'],
        updated_at=row['updated_at']
    )

@router.delete("/{server_id}")
async def delete_server(server_id: str):
    """Remove um servidor"""
    db = await get_db()

    cursor = await db.execute(
        "DELETE FROM servers WHERE id = ?",
        (server_id,)
    )

    await db.commit()

    if cursor.rowcount == 0:
        raise HTTPException(status_code=404, detail="Server not found")

    # TODO: Executar terraform destroy aqui

    return {"message": "Server deleted successfully"}

@router.post("/{server_id}/start")
async def start_server(server_id: str):
    """Inicia um servidor"""
    db = await get_db()

    # Verifica se servidor existe
    cursor = await db.execute(
        "SELECT status, container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    # TODO: Iniciar container Docker ou instância cloud

    await db.execute(
        "UPDATE servers SET status = ?, updated_at = ? WHERE id = ?",
        (ServerStatus.RUNNING.value, datetime.now().isoformat(), server_id)
    )
    await db.commit()

    return {"message": "Server started successfully"}

@router.post("/{server_id}/stop")
async def stop_server(server_id: str):
    """Para um servidor"""
    db = await get_db()

    cursor = await db.execute(
        "SELECT status FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    # TODO: Parar container Docker ou instância cloud

    await db.execute(
        "UPDATE servers SET status = ?, updated_at = ? WHERE id = ?",
        (ServerStatus.STOPPED.value, datetime.now().isoformat(), server_id)
    )
    await db.commit()

    return {"message": "Server stopped successfully"}

@router.post("/{server_id}/restart")
async def restart_server(server_id: str):
    """Reinicia um servidor"""
    await stop_server(server_id)
    await start_server(server_id)
    return {"message": "Server restarted successfully"}

@router.websocket("/console/{server_id}")
async def websocket_console(websocket: WebSocket, server_id: str):
    """WebSocket para console do servidor"""
    await websocket.accept()

    try:
        # TODO: Conectar com logs do container
        # Por enquanto, apenas mantém conexão aberta
        while True:
            data = await websocket.receive_text()
            # Echo de volta (substituir com comando real)
            await websocket.send_text(f"Received: {data}")

    except WebSocketDisconnect:
        print(f"Console disconnected for server {server_id}")
