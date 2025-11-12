"""
Serviço de agendamento para tarefas automáticas (backups, etc)
"""
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
import aiosqlite

class BackupScheduler:
    def __init__(self, interval_hours: int = 24):
        self.interval_hours = interval_hours
        self.docker_service = None
        self.running = False
        self.task = None
        self.db_path = None

    async def start(self):
        """Inicia o scheduler de backups"""
        if self.running:
            return

        # Lazy imports para evitar circular imports
        from web.backend.services.docker import DockerService
        from web.backend.database import DB_PATH

        self.docker_service = DockerService()
        self.db_path = str(DB_PATH)
        self.running = True
        self.task = asyncio.create_task(self._run_scheduler())
        print(f"Backup scheduler started (interval: {self.interval_hours}h)")

    async def stop(self):
        """Para o scheduler"""
        self.running = False
        if self.task:
            self.task.cancel()
            try:
                await self.task
            except asyncio.CancelledError:
                pass
        print("Backup scheduler stopped")

    async def _run_scheduler(self):
        """Loop principal do scheduler"""
        while self.running:
            try:
                await self._run_backup_cycle()
            except Exception as e:
                print(f"Error in backup cycle: {e}")

            # Aguarda até o próximo ciclo
            await asyncio.sleep(self.interval_hours * 3600)

    async def _run_backup_cycle(self):
        """Executa um ciclo de backup para todos os servidores ativos"""
        try:
            # Conecta ao banco de dados
            async with aiosqlite.connect(self.db_path) as db:
                db.row_factory = aiosqlite.Row

                # Busca todos os servidores rodando com containers
                cursor = await db.execute("""
                    SELECT id, name, container_id
                    FROM servers
                    WHERE status = 'running' AND container_id IS NOT NULL
                """)
                servers = await cursor.fetchall()

                print(f"[{datetime.now().isoformat()}] Running backup cycle for {len(servers)} servers")

                for server in servers:
                    try:
                        server_id = server['id']
                        server_name = server['name']
                        container_id = server['container_id']

                        print(f"  Creating backup for server: {server_name} ({server_id})")

                        # Cria backup
                        result = await self.docker_service.create_backup(container_id, server_name)

                        if result.get('status') == 'success':
                            print(f"    ✓ Backup created: {result.get('backup_name')}")

                            # Remove backups antigos (mantém apenas os últimos 7)
                            await self._cleanup_old_backups(container_id, server_name)
                        else:
                            print(f"    ✗ Backup failed: {result.get('error')}")

                    except Exception as e:
                        print(f"    ✗ Error backing up server {server.get('name', 'unknown')}: {e}")

                print(f"[{datetime.now().isoformat()}] Backup cycle completed")

        except Exception as e:
            print(f"Error in backup cycle: {e}")

    async def _cleanup_old_backups(self, container_id: str, server_name: str, keep_count: int = 7):
        """Remove backups antigos, mantendo apenas os últimos N"""
        try:
            # Lista backups do servidor
            exec_config = {
                "AttachStdout": True,
                "AttachStderr": True,
                "Cmd": ["sh", "-c", f"ls -1t /data/backups/backup_{server_name}_*.tar.gz 2>/dev/null || true"]
            }

            response = self.docker_service.client.post(f"/containers/{container_id}/exec", json=exec_config)
            if response.status_code != 201:
                return

            exec_id = response.json()['Id']
            start_response = self.docker_service.client.post(f"/exec/{exec_id}/start", json={"Detach": False})

            if start_response.status_code == 200:
                backups = start_response.text.strip().split('\n')
                # Remove headers do Docker stream
                backups = [b for b in backups if b and 'backup_' in b]

                if len(backups) > keep_count:
                    # Remove backups mais antigos
                    to_remove = backups[keep_count:]

                    for backup_file in to_remove:
                        # Remove escape characters
                        clean_backup = backup_file.strip()
                        if clean_backup:
                            rm_config = {
                                "AttachStdout": True,
                                "AttachStderr": True,
                                "Cmd": ["rm", "-f", clean_backup]
                            }
                            rm_response = self.docker_service.client.post(f"/containers/{container_id}/exec", json=rm_config)
                            if rm_response.status_code == 201:
                                exec_id = rm_response.json()['Id']
                                self.docker_service.client.post(f"/exec/{exec_id}/start", json={"Detach": False})
                                print(f"    Removed old backup: {clean_backup}")

        except Exception as e:
            print(f"Error cleaning up old backups: {e}")


# Instância global do scheduler
backup_scheduler = BackupScheduler(interval_hours=24)
