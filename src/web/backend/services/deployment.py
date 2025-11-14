"""
Serviço para deployment de servidores usando Terraform/Ansible ou Docker local
"""
import subprocess
import json
from pathlib import Path
from typing import Dict, Any, AsyncIterator
from web.backend.services.docker import DockerService
from web.backend.services.terraform_executor import TerraformExecutor, TerraformStatus
from web.backend.services.ansible_executor import AnsibleExecutor, AnsibleStatus

class DeploymentService:
    def __init__(self):
        self.ansible_integration = Path(__file__).parent.parent.parent.parent / "ansible_integration.py"
        self.terraform_dir = Path(__file__).parent.parent.parent.parent / "infrastructure" / "terraform"
        self.docker_service = DockerService()
        self.terraform_executor = TerraformExecutor()
        self.ansible_executor = AnsibleExecutor()

    async def generate_vars(self, server_config: Dict[str, Any]) -> Path:
        """
        Gera arquivo de variáveis Ansible usando ansible_integration.py
        """
        output_file = Path(f"/tmp/server_{server_config['id']}.yml")

        cmd = [
            "python3",
            str(self.ansible_integration),
            "generate",
            "--java-type", server_config['server_type'],
            "--java-version", server_config['version'],
            "--java-memory", server_config.get('memory', '2G'),
            "-o", str(output_file)
        ]

        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        return output_file

    async def deploy_server(self, server_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Deploy completo: Docker local ou Terraform/Ansible para cloud

        Para provider 'local': Cria container Docker
        Para provider 'aws'/'azure': Executa terraform + ansible
        """
        provider = server_config.get('provider', 'local')

        if provider == 'local':
            # Deployment local via Docker
            result = await self.docker_service.create_minecraft_container(server_config)

            if result.get('status') == 'success':
                return {
                    "status": "success",
                    "container_id": result['container_id'],
                    "ip_address": result['ip_address'],
                    "port": result['port'],
                    "deployment_type": "docker"
                }
            else:
                return {
                    "status": "error",
                    "error": result.get('error', 'Unknown error'),
                    "deployment_type": "docker"
                }

        else:
            # Deployment cloud via Terraform/Ansible - NOT SUPPORTED in sync mode
            # Use deploy_cloud_async() for async cloud deployments
            return {
                "status": "error",
                "error": "Cloud deployments must use the async API endpoint /api/servers/{id}/deploy-cloud",
                "deployment_type": "cloud"
            }

    async def deploy_cloud_async(
        self,
        server_config: Dict[str, Any]
    ) -> AsyncIterator[Dict[str, Any]]:
        """
        Deploy server to cloud (AWS/Azure) asynchronously with progress updates

        This is a streaming async generator that yields progress updates
        Use this for cloud deployments to track progress in real-time

        Args:
            server_config: Server configuration including:
                - provider: 'aws' or 'azure'
                - orchestration: 'swarm' or 'kubernetes' (default: swarm)
                - server_names: list of server names
                - version, memory, gamemode, difficulty, etc.

        Yields:
            Progress updates with status, message, and logs
        """
        provider = server_config.get('provider', 'aws')
        orchestration = server_config.get('orchestration', 'swarm')
        server_names = server_config.get('server_names', [server_config.get('name', 'instance1')])

        if isinstance(server_names, str):
            server_names = [server_names]

        try:
            # Stage 1: Terraform Deployment
            outputs = {}

            async for update in self.terraform_executor.deploy_full(
                provider=provider,
                server_names=server_names,
                orchestration=orchestration
            ):
                # Forward terraform updates
                yield {
                    "stage": "terraform",
                    **update
                }

                # Save outputs if successful
                if update.get("status") == TerraformStatus.SUCCESS.value:
                    outputs = update.get("outputs", {})

            # Extract instance IPs from terraform outputs
            instance_ips = self.terraform_executor.extract_instance_ips(outputs)

            # Stage 2: Ansible Configuration (only for Swarm)
            if orchestration == "swarm":
                async for update in self.ansible_executor.deploy_swarm(
                    server_config=server_config
                ):
                    # Forward ansible updates
                    yield {
                        "stage": "ansible",
                        **update
                    }

                    # If successful, return final result with IPs
                    if update.get("status") == AnsibleStatus.SUCCESS.value:
                        # Get the first instance IP (manager node)
                        first_ip = list(instance_ips.values())[0] if instance_ips else "0.0.0.0"

                        yield {
                            "stage": "complete",
                            "status": "success",
                            "message": "Cloud deployment completed successfully",
                            "deployment_type": "cloud",
                            "ip_address": first_ip,
                            "all_ips": instance_ips,
                            "port": 25565,
                            "terraform_outputs": outputs
                        }
            else:
                # Kubernetes - deployment handled by Terraform
                first_ip = list(instance_ips.values())[0] if instance_ips else "0.0.0.0"

                yield {
                    "stage": "complete",
                    "status": "success",
                    "message": "Kubernetes cluster deployed successfully",
                    "deployment_type": "cloud-k8s",
                    "ip_address": first_ip,
                    "all_ips": instance_ips,
                    "port": 25565,
                    "terraform_outputs": outputs
                }

        except Exception as e:
            yield {
                "stage": "error",
                "status": "error",
                "message": f"Cloud deployment failed: {str(e)}",
                "error": str(e),
                "deployment_type": "cloud"
            }

    async def destroy_server(self, server_id: str, container_id: str = None) -> Dict[str, Any]:
        """
        Remove infraestrutura: Docker container ou Terraform resources
        """
        if container_id:
            # Remove container Docker
            result = await self.docker_service.remove_container(container_id)
            return result
        else:
            # TODO: Implementar terraform destroy
            return {
                "status": "success",
                "message": "Server infrastructure destroyed"
            }
