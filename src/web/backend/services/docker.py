"""
Serviço para gerenciar containers Docker locais
"""
import docker
from typing import List, Dict, Any, Optional

class DockerService:
    def __init__(self):
        try:
            self.client = docker.from_env()
        except Exception:
            self.client = None

    async def list_containers(self, all: bool = False) -> List[Dict[str, Any]]:
        """
        Lista containers Minecraft rodando
        """
        if not self.client:
            return []

        containers = self.client.containers.list(all=all, filters={"label": "minecraft"})

        return [
            {
                "id": c.id[:12],
                "name": c.name,
                "status": c.status,
                "image": c.image.tags[0] if c.image.tags else "unknown",
            }
            for c in containers
        ]

    async def get_container(self, container_id: str):
        """
        Obtém informações de um container específico
        """
        if not self.client:
            return None

        try:
            return self.client.containers.get(container_id)
        except docker.errors.NotFound:
            return None

    async def start_container(self, container_id: str) -> Dict[str, Any]:
        """
        Inicia um container
        """
        if not self.client:
            return {"error": "Docker not available"}

        try:
            container = self.client.containers.get(container_id)
            container.start()
            return {"status": "started", "container_id": container_id}
        except Exception as e:
            return {"error": str(e)}

    async def stop_container(self, container_id: str) -> Dict[str, Any]:
        """
        Para um container
        """
        if not self.client:
            return {"error": "Docker not available"}

        try:
            container = self.client.containers.get(container_id)
            container.stop()
            return {"status": "stopped", "container_id": container_id}
        except Exception as e:
            return {"error": str(e)}

    async def restart_container(self, container_id: str) -> Dict[str, Any]:
        """
        Reinicia um container
        """
        if not self.client:
            return {"error": "Docker not available"}

        try:
            container = self.client.containers.get(container_id)
            container.restart()
            return {"status": "restarted", "container_id": container_id}
        except Exception as e:
            return {"error": str(e)}

    async def get_logs(self, container_id: str, tail: int = 100) -> str:
        """
        Retorna logs de um container para WebSocket
        """
        if not self.client:
            return "Docker not available"

        try:
            container = self.client.containers.get(container_id)
            logs = container.logs(tail=tail, stream=False)
            return logs.decode('utf-8')
        except Exception as e:
            return f"Error getting logs: {str(e)}"

    async def stream_logs(self, container_id: str):
        """
        Stream de logs em tempo real (generator)
        """
        if not self.client:
            yield "Docker not available"
            return

        try:
            container = self.client.containers.get(container_id)
            for line in container.logs(stream=True, follow=True):
                yield line.decode('utf-8')
        except Exception as e:
            yield f"Error streaming logs: {str(e)}"

    async def exec_command(self, container_id: str, command: str) -> Dict[str, Any]:
        """
        Executa um comando em um container (para console)
        """
        if not self.client:
            return {"error": "Docker not available"}

        try:
            container = self.client.containers.get(container_id)
            result = container.exec_run(command)
            return {
                "exit_code": result.exit_code,
                "output": result.output.decode('utf-8')
            }
        except Exception as e:
            return {"error": str(e)}
