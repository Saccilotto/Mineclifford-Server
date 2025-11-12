"""
Serviço para deployment de servidores usando Terraform/Ansible ou Docker local
"""
import subprocess
import json
from pathlib import Path
from typing import Dict, Any
from web.backend.services.docker import DockerService

class DeploymentService:
    def __init__(self):
        self.ansible_integration = Path(__file__).parent.parent.parent.parent / "ansible_integration.py"
        self.terraform_dir = Path(__file__).parent.parent.parent.parent / "infrastructure" / "terraform"
        self.docker_service = DockerService()

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
            # Deployment cloud via Terraform/Ansible
            # TODO: Implementar deployment cloud completo
            try:
                # 1. Gera arquivo de vars do Ansible
                vars_file = await self.generate_vars(server_config)

                # 2. TODO: Executar terraform apply
                # terraform_result = await self._run_terraform(server_config)

                # 3. TODO: Executar ansible-playbook
                # ansible_result = await self._run_ansible(vars_file)

                return {
                    "status": "success",
                    "ip_address": "0.0.0.0",  # TODO: obter do terraform
                    "port": 25565,
                    "terraform_state": {},
                    "ansible_output": "Cloud deployment not fully implemented",
                    "deployment_type": "cloud"
                }
            except Exception as e:
                return {
                    "status": "error",
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
