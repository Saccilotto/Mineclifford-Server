from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from typing import List
import uuid
import json
import asyncio
from datetime import datetime

from web.backend.models.server import ServerCreate, ServerResponse, ServerStatus
from web.backend.database import get_db
from web.backend.services.docker import DockerService
from web.backend.services.deployment import DeploymentService

router = APIRouter(prefix="/api/servers", tags=["servers"])
docker_service = DockerService()
deployment_service = DeploymentService()

async def deploy_server(server_id: str, server_config: ServerCreate):
    """
    Função assíncrona para fazer deploy do servidor
    """
    db = await get_db()

    try:
        # Prepara config para deployment
        config_dict = server_config.model_dump()
        config_dict['id'] = server_id

        # Executa deployment
        result = await deployment_service.deploy_server(config_dict)

        if result.get('status') == 'success':
            # Atualiza servidor com informações do deployment
            await db.execute("""
                UPDATE servers
                SET status = ?,
                    container_id = ?,
                    ip_address = ?,
                    port = ?,
                    updated_at = ?
                WHERE id = ?
            """, (
                ServerStatus.RUNNING.value,
                result.get('container_id'),
                result.get('ip_address'),
                result.get('port', 25565),
                datetime.now().isoformat(),
                server_id
            ))
            await db.commit()
            print(f"Server {server_id} deployed successfully")
        else:
            # Marca como erro
            await db.execute("""
                UPDATE servers
                SET status = ?,
                    updated_at = ?
                WHERE id = ?
            """, (
                ServerStatus.ERROR.value,
                datetime.now().isoformat(),
                server_id
            ))
            await db.commit()
            print(f"Server {server_id} deployment failed: {result.get('error')}")

    except Exception as e:
        print(f"Error deploying server {server_id}: {str(e)}")
        # Marca como erro
        await db.execute("""
            UPDATE servers
            SET status = ?,
                updated_at = ?
            WHERE id = ?
        """, (
            ServerStatus.ERROR.value,
            datetime.now().isoformat(),
            server_id
        ))
        await db.commit()

@router.get("/", response_model=List[ServerResponse])
async def list_servers():
    """Lista todos os servidores"""
    db = await get_db()

    cursor = await db.execute("""
        SELECT id, name, server_type, version, status,
               ip_address, port, container_id, created_at, updated_at
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
            container_id=row['container_id'],
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

        # Inicia deployment assíncrono
        asyncio.create_task(deploy_server(server_id, server))

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
               ip_address, port, container_id, created_at, updated_at
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
        container_id=row['container_id'],
        created_at=row['created_at'],
        updated_at=row['updated_at']
    )

@router.delete("/{server_id}")
async def delete_server(server_id: str):
    """Remove um servidor"""
    db = await get_db()

    # Busca container_id antes de deletar
    cursor = await db.execute(
        "SELECT container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    container_id = row['container_id']

    # Remove do banco de dados
    await db.execute(
        "DELETE FROM servers WHERE id = ?",
        (server_id,)
    )
    await db.commit()

    # Remove infraestrutura (container ou cloud resources)
    if container_id:
        await deployment_service.destroy_server(server_id, container_id)

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

    container_id = row['container_id']

    if container_id:
        # Inicia container Docker
        result = await docker_service.start_container(container_id)

        if "error" in result:
            raise HTTPException(status_code=500, detail=result['error'])

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
        "SELECT status, container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    container_id = row['container_id']

    if container_id:
        # Para container Docker
        result = await docker_service.stop_container(container_id)

        if "error" in result:
            raise HTTPException(status_code=500, detail=result['error'])

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
    """WebSocket para console do servidor com logs em tempo real"""
    await websocket.accept()

    db = await get_db()

    # Busca o container_id do servidor
    cursor = await db.execute(
        "SELECT container_id, status FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        await websocket.send_text("Error: Server not found")
        await websocket.close()
        return

    container_id = row['container_id']
    status = row['status']

    if not container_id:
        await websocket.send_text("Waiting for server deployment...")

        # Aguarda até que o container_id seja definido (máximo 60 segundos)
        for _ in range(60):
            await asyncio.sleep(1)
            cursor = await db.execute(
                "SELECT container_id, status FROM servers WHERE id = ?",
                (server_id,)
            )
            row = await cursor.fetchone()
            if row and row['container_id']:
                container_id = row['container_id']
                await websocket.send_text(f"\r\nServer deployment started! Container: {container_id[:12]}\r\n")
                break
        else:
            await websocket.send_text("Error: Server deployment timeout")
            await websocket.close()
            return

    # Inicia streaming de logs em background
    async def stream_logs_task():
        try:
            async for log_line in docker_service.stream_logs(container_id):
                await websocket.send_text(log_line)
        except Exception as e:
            await websocket.send_text(f"\r\nError streaming logs: {str(e)}\r\n")

    log_task = asyncio.create_task(stream_logs_task())

    try:
        # Recebe comandos do usuário
        while True:
            data = await websocket.receive_text()

            if data.strip():
                # Executa comando no container
                result = await docker_service.exec_command(container_id, data.strip())

                if "error" in result:
                    await websocket.send_text(f"\r\nError: {result['error']}\r\n")
                else:
                    await websocket.send_text(result.get('output', ''))

    except WebSocketDisconnect:
        log_task.cancel()
        print(f"Console disconnected for server {server_id}")

@router.post("/{server_id}/backup")
async def create_backup(server_id: str):
    """Cria backup do servidor"""
    db = await get_db()

    # Busca informações do servidor
    cursor = await db.execute(
        "SELECT name, container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    if not row['container_id']:
        raise HTTPException(status_code=400, detail="Server has no container (not deployed)")

    # Cria backup
    result = await docker_service.create_backup(row['container_id'], row['name'])

    if "error" in result:
        raise HTTPException(status_code=500, detail=result['error'])

    return {
        "message": "Backup created successfully",
        "backup_name": result.get('backup_name'),
        "timestamp": result.get('timestamp')
    }

@router.post("/{server_id}/restore")
async def restore_backup(server_id: str, backup_name: str):
    """Restaura backup do servidor"""
    db = await get_db()

    # Busca container_id
    cursor = await db.execute(
        "SELECT container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    if not row['container_id']:
        raise HTTPException(status_code=400, detail="Server has no container (not deployed)")

    # Restaura backup
    result = await docker_service.restore_backup(row['container_id'], backup_name)

    if "error" in result:
        raise HTTPException(status_code=500, detail=result['error'])

    # Atualiza status no banco
    await db.execute(
        "UPDATE servers SET status = ?, updated_at = ? WHERE id = ?",
        (ServerStatus.RUNNING.value, datetime.now().isoformat(), server_id)
    )
    await db.commit()

    return {
        "message": result.get('message', 'Backup restored successfully'),
        "backup_name": backup_name
    }

@router.get("/{server_id}/backups")
async def list_backups(server_id: str):
    """Lista backups disponíveis do servidor"""
    db = await get_db()

    # Busca container_id
    cursor = await db.execute(
        "SELECT container_id FROM servers WHERE id = ?",
        (server_id,)
    )
    row = await cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Server not found")

    if not row['container_id']:
        raise HTTPException(status_code=400, detail="Server has no container (not deployed)")

    # Lista backups
    result = await docker_service.list_backups(row['container_id'])

    if "error" in result:
        raise HTTPException(status_code=500, detail=result['error'])

    return {
        "backups": result.get('backups', '')
    }
