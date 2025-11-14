"""
Ansible Executor Service
Manages Ansible playbook execution for server configuration
"""
import asyncio
import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional, AsyncIterator
from enum import Enum


class AnsibleStatus(str, Enum):
    PREPARING = "preparing"
    RUNNING = "running"
    SUCCESS = "success"
    ERROR = "error"


class AnsibleExecutor:
    """
    Executes Ansible playbooks asynchronously
    """

    def __init__(self, project_root: Optional[Path] = None):
        if project_root is None:
            # Navigate from src/web/backend/services/ to project root
            self.project_root = Path(__file__).parent.parent.parent.parent.parent
        else:
            self.project_root = project_root

        self.ansible_dir = self.project_root / "deployment" / "ansible"
        self.inventory_file = self.project_root / "static_ip.ini"

    def _create_vars_file(
        self,
        server_config: Dict[str, Any],
        output_path: Path
    ) -> None:
        """
        Create Ansible variables file from server configuration

        Args:
            server_config: Server configuration dictionary
            output_path: Where to save the vars file
        """
        # Determine swarm configuration
        server_names = server_config.get('server_names', ['instance1'])
        single_node_swarm = len(server_names) == 1

        vars_content = {
            # Minecraft Configuration Variables
            'minecraft_java_version': server_config.get('version', 'latest'),
            'minecraft_java_memory': server_config.get('memory', '2G'),
            'minecraft_java_gamemode': server_config.get('gamemode', 'survival'),
            'minecraft_java_difficulty': server_config.get('difficulty', 'normal'),
            'minecraft_java_motd': f"Mineclifford {server_config.get('name', 'Server')}",
            'minecraft_java_allow_nether': True,
            'minecraft_java_enable_command_block': True,
            'minecraft_java_spawn_protection': 0,
            'minecraft_java_view_distance': 10,

            # Bedrock Edition (if enabled)
            'minecraft_bedrock_enabled': server_config.get('enable_bedrock', False),
            'minecraft_bedrock_version': server_config.get('version', 'latest'),
            'minecraft_bedrock_memory': '1G',
            'minecraft_bedrock_gamemode': server_config.get('gamemode', 'survival'),
            'minecraft_bedrock_difficulty': server_config.get('difficulty', 'normal'),
            'minecraft_bedrock_server_name': f"Mineclifford {server_config.get('name', 'Bedrock')}",
            'minecraft_bedrock_allow_cheats': False,

            # Monitoring Configuration
            'rcon_password': 'minecraft',  # TODO: Generate secure password
            'grafana_password': 'admin',  # TODO: Generate secure password
            'timezone': server_config.get('timezone', 'America/Sao_Paulo'),

            # Server Names
            'server_names': server_names,

            # Swarm Configuration
            'single_node_swarm': single_node_swarm
        }

        # Write to file
        with open(output_path, 'w') as f:
            yaml.dump(vars_content, f, default_flow_style=False)

    async def _run_playbook(
        self,
        playbook_path: Path,
        inventory_path: Path,
        vars_file: Optional[Path] = None,
        extra_vars: Optional[Dict[str, Any]] = None
    ) -> AsyncIterator[str]:
        """
        Run an Ansible playbook and stream output

        Args:
            playbook_path: Path to the playbook file
            inventory_path: Path to the inventory file
            vars_file: Path to variables file
            extra_vars: Additional variables to pass

        Yields:
            Playbook output lines
        """
        command = [
            "ansible-playbook",
            "-i", str(inventory_path),
            str(playbook_path)
        ]

        # Add vars file if provided
        if vars_file:
            command.extend(["-e", f"@{vars_file}"])

        # Add extra vars if provided
        if extra_vars:
            for key, value in extra_vars.items():
                command.extend(["-e", f"{key}={value}"])

        # Set environment for colored output
        env = os.environ.copy()
        env['ANSIBLE_FORCE_COLOR'] = 'true'
        env['PYTHONIOENCODING'] = 'utf-8'
        env['ANSIBLE_HOST_KEY_CHECKING'] = 'False'

        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(self.ansible_dir),
            env=env
        )

        # Stream output
        while True:
            line = await process.stdout.readline()
            if not line:
                break

            yield line.decode('utf-8', errors='ignore').strip()

        # Wait for process to complete
        await process.wait()

        if process.returncode != 0:
            raise Exception(f"Ansible playbook failed with return code {process.returncode}")

    async def test_connectivity(
        self,
        inventory_path: Optional[Path] = None
    ) -> AsyncIterator[str]:
        """
        Test connectivity to all hosts in inventory

        Args:
            inventory_path: Path to inventory file (defaults to static_ip.ini)

        Yields:
            Connectivity test output
        """
        if inventory_path is None:
            inventory_path = self.inventory_file

        command = [
            "ansible",
            "-i", str(inventory_path),
            "all",
            "-m", "ping"
        ]

        env = os.environ.copy()
        env['ANSIBLE_HOST_KEY_CHECKING'] = 'False'

        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=env
        )

        while True:
            line = await process.stdout.readline()
            if not line:
                break

            yield line.decode('utf-8', errors='ignore').strip()

        await process.wait()

    async def deploy_swarm(
        self,
        server_config: Dict[str, Any],
        inventory_path: Optional[Path] = None
    ) -> AsyncIterator[Dict[str, Any]]:
        """
        Deploy Minecraft server using Docker Swarm

        Args:
            server_config: Server configuration dictionary
            inventory_path: Path to Ansible inventory file

        Yields:
            Status updates with progress information
        """
        try:
            if inventory_path is None:
                inventory_path = self.inventory_file

            # Check if inventory exists
            if not inventory_path.exists():
                raise FileNotFoundError(
                    f"Inventory file not found: {inventory_path}. "
                    "Terraform must be executed first to generate inventory."
                )

            # Step 1: Create vars file
            yield {
                "status": AnsibleStatus.PREPARING.value,
                "message": "Preparing Ansible variables...",
                "logs": []
            }

            vars_file = Path(f"/tmp/minecraft_vars_{server_config.get('id', 'temp')}.yml")
            self._create_vars_file(server_config, vars_file)

            # Step 2: Test connectivity
            yield {
                "status": AnsibleStatus.PREPARING.value,
                "message": "Testing connectivity to hosts...",
                "logs": []
            }

            connectivity_logs = []
            async for line in self.test_connectivity(inventory_path):
                connectivity_logs.append(line)
                yield {
                    "status": AnsibleStatus.PREPARING.value,
                    "message": line,
                    "logs": connectivity_logs
                }

            # Step 3: Run swarm setup playbook
            yield {
                "status": AnsibleStatus.RUNNING.value,
                "message": "Executing Ansible playbook...",
                "logs": []
            }

            playbook_path = self.ansible_dir / "swarm_setup.yml"
            playbook_logs = []

            async for line in self._run_playbook(
                playbook_path,
                inventory_path,
                vars_file
            ):
                playbook_logs.append(line)
                yield {
                    "status": AnsibleStatus.RUNNING.value,
                    "message": line,
                    "logs": playbook_logs
                }

            # Cleanup vars file
            if vars_file.exists():
                vars_file.unlink()

            yield {
                "status": AnsibleStatus.SUCCESS.value,
                "message": "Ansible deployment completed successfully",
                "logs": []
            }

        except FileNotFoundError as e:
            yield {
                "status": AnsibleStatus.ERROR.value,
                "message": str(e),
                "error": str(e),
                "logs": []
            }

        except Exception as e:
            yield {
                "status": AnsibleStatus.ERROR.value,
                "message": f"Ansible deployment failed: {str(e)}",
                "error": str(e),
                "logs": []
            }

    async def deploy_kubernetes(
        self,
        server_config: Dict[str, Any],
        namespace: str = "mineclifford"
    ) -> AsyncIterator[Dict[str, Any]]:
        """
        Deploy Minecraft server to Kubernetes cluster

        Args:
            server_config: Server configuration dictionary
            namespace: Kubernetes namespace

        Yields:
            Status updates with progress information
        """
        # TODO: Implement Kubernetes deployment via kubectl
        yield {
            "status": AnsibleStatus.ERROR.value,
            "message": "Kubernetes deployment not yet implemented",
            "error": "Not implemented",
            "logs": []
        }
