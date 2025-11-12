"""
Serviço para gerenciar containers Docker locais usando API REST via httpx
"""
import httpx
import json
from typing import List, Dict, Any, Optional

class DockerService:
    def __init__(self):
        try:
            # Usa httpx com suporte nativo a Unix socket
            self.client = httpx.Client(
                transport=httpx.HTTPTransport(uds="/var/run/docker.sock"),
                base_url="http://localhost"
            )

            # Testa a conexão
            response = self.client.get("/_ping")
            if response.status_code == 200:
                print("Docker API connected successfully via httpx")
                self.available = True
            else:
                print("Docker API not responding")
                self.available = False
        except Exception as e:
            print(f"Docker not available: {e}")
            self.available = False
            self.client = None

    async def list_containers(self, all: bool = False) -> List[Dict[str, Any]]:
        """
        Lista containers Minecraft rodando
        """
        if not self.available or not self.client:
            return []

        try:
            params = {'all': all, 'filters': json.dumps({"label": ["minecraft=true"]})}
            response = self.client.get("/containers/json", params=params)

            if response.status_code != 200:
                return []

            containers = response.json()
            return [
                {
                    "id": c['Id'][:12],
                    "name": c['Names'][0].lstrip('/'),
                    "status": c['State'],
                    "image": c['Image'],
                }
                for c in containers
            ]
        except Exception as e:
            print(f"Error listing containers: {e}")
            return []

    async def get_container(self, container_id: str) -> Optional[Dict[str, Any]]:
        """
        Obtém informações de um container específico
        """
        if not self.available or not self.client:
            return None

        try:
            response = self.client.get(f"/containers/{container_id}/json")

            if response.status_code == 200:
                return response.json()
            return None
        except Exception:
            return None

    async def start_container(self, container_id: str) -> Dict[str, Any]:
        """
        Inicia um container
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            response = self.client.post(f"/containers/{container_id}/start")

            if response.status_code in [204, 304]:  # 204 = started, 304 = already started
                return {"status": "started", "container_id": container_id}
            else:
                return {"error": f"Failed to start container: {response.text}"}
        except Exception as e:
            return {"error": str(e)}

    async def stop_container(self, container_id: str) -> Dict[str, Any]:
        """
        Para um container
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            response = self.client.post(f"/containers/{container_id}/stop")

            if response.status_code in [204, 304]:  # 204 = stopped, 304 = already stopped
                return {"status": "stopped", "container_id": container_id}
            else:
                return {"error": f"Failed to stop container: {response.text}"}
        except Exception as e:
            return {"error": str(e)}

    async def restart_container(self, container_id: str) -> Dict[str, Any]:
        """
        Reinicia um container
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            response = self.client.post(f"/containers/{container_id}/restart")

            if response.status_code == 204:
                return {"status": "restarted", "container_id": container_id}
            else:
                return {"error": f"Failed to restart container: {response.text}"}
        except Exception as e:
            return {"error": str(e)}

    async def get_logs(self, container_id: str, tail: int = 100) -> str:
        """
        Retorna logs de um container para WebSocket
        """
        if not self.available or not self.client:
            return "Docker not available"

        try:
            params = {'stdout': True, 'stderr': True, 'tail': tail}
            response = self.client.get(
                f"/containers/{container_id}/logs",
                params=params
            )

            if response.status_code == 200:
                return response.text
            else:
                return f"Error getting logs: {response.text}"
        except Exception as e:
            return f"Error getting logs: {str(e)}"

    async def stream_logs(self, container_id: str):
        """
        Stream de logs em tempo real (async generator)
        """
        import asyncio

        if not self.available or not self.client:
            yield "Docker not available\r\n"
            return

        try:
            params = {'stdout': True, 'stderr': True, 'follow': True, 'timestamps': False}

            # httpx streaming
            with self.client.stream("GET", f"/containers/{container_id}/logs", params=params) as response:
                if response.status_code != 200:
                    yield f"Error streaming logs: {response.text}\r\n"
                    return

                # Stream logs linha por linha
                for line in response.iter_lines():
                    if line:
                        # Remove headers do Docker stream protocol (8 bytes)
                        clean_line = line
                        if len(line) > 8 and line[0:1] in [b'\x00', b'\x01', b'\x02']:
                            clean_line = line[8:]

                        yield clean_line.decode('utf-8', errors='ignore') + '\r\n'
                        await asyncio.sleep(0)  # Permite que outras tasks executem
        except Exception as e:
            yield f"Error streaming logs: {str(e)}\r\n"

    async def exec_command(self, container_id: str, command: str) -> Dict[str, Any]:
        """
        Executa um comando em um container (para console)
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            # Cria exec instance
            exec_config = {
                "AttachStdout": True,
                "AttachStderr": True,
                "Cmd": ["/bin/sh", "-c", command]
            }

            response = self.client.post(
                f"/containers/{container_id}/exec",
                json=exec_config
            )

            if response.status_code != 201:
                return {"error": f"Failed to create exec: {response.text}"}

            exec_id = response.json()['Id']

            # Inicia exec
            start_config = {"Detach": False}
            response = self.client.post(
                f"/exec/{exec_id}/start",
                json=start_config
            )

            if response.status_code == 200:
                return {
                    "exit_code": 0,
                    "output": response.text
                }
            else:
                return {"error": f"Failed to start exec: {response.text}"}
        except Exception as e:
            return {"error": str(e)}

    async def pull_image(self, image: str) -> Dict[str, Any]:
        """
        Pull de uma imagem Docker
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            print(f"Pulling Docker image: {image}")
            # Docker API usa query params para fromImage
            params = {'fromImage': image}

            # Pull é uma operação de streaming, mas vamos usar timeout maior
            with self.client.stream("POST", "/images/create", params=params, timeout=300.0) as response:
                if response.status_code != 200:
                    return {"error": f"Failed to pull image: {response.text}"}

                # Lê o stream até o final
                for line in response.iter_lines():
                    if line:
                        # Imprime progresso (opcional)
                        try:
                            data = json.loads(line)
                            if 'status' in data:
                                print(f"  {data['status']}", end='')
                                if 'progress' in data:
                                    print(f" {data['progress']}", end='')
                                print()
                        except:
                            pass

            print(f"Image {image} pulled successfully")
            return {"status": "success"}
        except Exception as e:
            return {"error": f"Failed to pull image: {str(e)}"}

    async def create_minecraft_container(self, server_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Cria e inicia um container Minecraft usando Docker API REST via httpx
        """
        if not self.available or not self.client:
            return {"error": "Docker not available", "status": "error"}

        try:
            server_type = server_config.get('server_type', 'vanilla').upper()
            version = server_config.get('version', 'LATEST')
            memory = server_config.get('memory', '2G')
            max_players = server_config.get('max_players', 20)
            gamemode = server_config.get('gamemode', 'survival')
            difficulty = server_config.get('difficulty', 'normal')
            server_name = server_config.get('name', 'Minecraft Server')
            server_id = server_config.get('id', 'unknown')

            # Pull da imagem se necessário
            image_name = "itzg/minecraft-server:latest"
            pull_result = await self.pull_image(image_name)
            if pull_result.get('error'):
                return {"error": f"Failed to pull image: {pull_result['error']}", "status": "error"}

            # Configuração do container para API REST
            container_config = {
                "Image": image_name,
                "Env": [
                    "EULA=TRUE",
                    f"TYPE={server_type}",
                    f"VERSION={version}",
                    f"MEMORY={memory}",
                    f"MAX_PLAYERS={max_players}",
                    f"MODE={gamemode}",
                    f"DIFFICULTY={difficulty}",
                    f"SERVER_NAME={server_name}",
                ],
                "HostConfig": {
                    "Binds": [f"minecraft_data_{server_id}:/data"],
                    "PortBindings": {
                        "25565/tcp": [{"HostPort": ""}]  # Porta aleatória
                    },
                    "RestartPolicy": {
                        "Name": "unless-stopped"
                    }
                },
                "Labels": {
                    "minecraft": "true",
                    "server_id": server_id,
                    "server_name": server_name
                },
                "ExposedPorts": {
                    "25565/tcp": {}
                }
            }

            # Cria o container
            response = self.client.post(
                "/containers/create",
                params={'name': f'minecraft_{server_id[:8]}'},
                json=container_config
            )

            if response.status_code != 201:
                return {"error": f"Failed to create container: {response.text}", "status": "error"}

            container_data = response.json()
            container_id = container_data['Id']

            # Inicia o container
            start_response = self.client.post(f"/containers/{container_id}/start")

            if start_response.status_code not in [204, 304]:
                return {"error": f"Failed to start container: {start_response.text}", "status": "error"}

            # Obtém informações do container para pegar a porta
            inspect_response = self.client.get(f"/containers/{container_id}/json")

            if inspect_response.status_code != 200:
                return {"error": "Failed to inspect container", "status": "error"}

            container_info = inspect_response.json()
            port_bindings = container_info.get('NetworkSettings', {}).get('Ports', {})
            host_port = '25565'

            if '25565/tcp' in port_bindings and port_bindings['25565/tcp']:
                host_port = port_bindings['25565/tcp'][0]['HostPort']

            return {
                "status": "success",
                "container_id": container_id,
                "container_name": f'minecraft_{server_id[:8]}',
                "port": int(host_port),
                "ip_address": "127.0.0.1"
            }

        except Exception as e:
            return {"error": str(e), "status": "error"}

    async def remove_container(self, container_id: str, remove_volumes: bool = True) -> Dict[str, Any]:
        """
        Remove um container e opcionalmente seus volumes
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            # Para o container primeiro
            await self.stop_container(container_id)

            # Remove o container
            params = {'v': remove_volumes}
            response = self.client.delete(
                f"/containers/{container_id}",
                params=params
            )

            if response.status_code == 204:
                return {"status": "removed", "container_id": container_id}
            else:
                return {"error": f"Failed to remove container: {response.text}"}
        except Exception as e:
            return {"error": str(e)}

    async def create_backup(self, container_id: str, server_name: str) -> Dict[str, Any]:
        """
        Cria backup do mundo do servidor
        """
        if not self.available or not self.client:
            return {"error": "Docker not available"}

        try:
            import datetime
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"backup_{server_name}_{timestamp}.tar"

            # Cria arquivo tar do volume /data
            exec_config = {
                "AttachStdout": True,
                "AttachStderr": True,
                "Cmd": ["tar", "-czf", f"/tmp/{backup_name}", "-C", "/data", "."]
            }

            response = self.client.post(f"/containers/{container_id}/exec", json=exec_config)
            if response.status_code != 201:
                return {"error": "Failed to create backup exec"}

            exec_id = response.json()['Id']
            start_response = self.client.post(f"/exec/{exec_id}/start", json={"Detach": False})

            if start_response.status_code == 200:
                return {
                    "status": "success",
                    "backup_name": backup_name,
                    "timestamp": timestamp
                }
            else:
                return {"error": "Failed to create backup"}
        except Exception as e:
            return {"error": str(e)}
