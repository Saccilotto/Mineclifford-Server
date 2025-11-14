"""
Terraform Executor Service
Manages Terraform operations for cloud infrastructure provisioning
"""
import asyncio
import json
import os
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional, AsyncIterator
from enum import Enum


class TerraformStatus(str, Enum):
    INITIALIZING = "initializing"
    PLANNING = "planning"
    APPLYING = "applying"
    DESTROYING = "destroying"
    SUCCESS = "success"
    ERROR = "error"


class TerraformExecutor:
    """
    Executes Terraform commands asynchronously and manages infrastructure state
    """

    def __init__(self, project_root: Optional[Path] = None):
        if project_root is None:
            # Navigate from src/web/backend/services/ to project root
            self.project_root = Path(__file__).parent.parent.parent.parent.parent
        else:
            self.project_root = project_root

        self.terraform_dir = self.project_root / "terraform"

    def _get_provider_dir(self, provider: str, orchestration: str = "swarm") -> Path:
        """
        Get the Terraform directory for the specified provider

        Args:
            provider: 'aws' or 'azure'
            orchestration: 'swarm' or 'kubernetes'

        Returns:
            Path to terraform directory
        """
        base_dir = self.terraform_dir / provider

        if orchestration == "kubernetes":
            return base_dir / "kubernetes"

        return base_dir

    async def _run_command(
        self,
        command: list[str],
        cwd: Path,
        env: Optional[Dict[str, str]] = None
    ) -> AsyncIterator[str]:
        """
        Run a subprocess command and stream output line by line

        Args:
            command: Command and arguments as list
            cwd: Working directory
            env: Environment variables

        Yields:
            Output lines as they're produced
        """
        # Merge environment variables
        full_env = os.environ.copy()
        if env:
            full_env.update(env)

        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(cwd),
            env=full_env
        )

        # Stream output
        while True:
            line = await process.stdout.readline()
            if not line:
                break

            yield line.decode('utf-8').strip()

        # Wait for process to complete
        await process.wait()

        if process.returncode != 0:
            raise subprocess.CalledProcessError(
                process.returncode,
                command,
                f"Command failed with return code {process.returncode}"
            )

    async def init(
        self,
        provider: str,
        orchestration: str = "swarm"
    ) -> AsyncIterator[str]:
        """
        Initialize Terraform in the provider directory

        Args:
            provider: 'aws' or 'azure'
            orchestration: 'swarm' or 'kubernetes'

        Yields:
            Terraform init output lines
        """
        tf_dir = self._get_provider_dir(provider, orchestration)

        command = ["terraform", "init", "-no-color"]

        async for line in self._run_command(command, tf_dir):
            yield line

    async def plan(
        self,
        provider: str,
        server_names: list[str],
        orchestration: str = "swarm",
        vars: Optional[Dict[str, Any]] = None
    ) -> AsyncIterator[str]:
        """
        Create a Terraform execution plan

        Args:
            provider: 'aws' or 'azure'
            server_names: List of server instance names
            orchestration: 'swarm' or 'kubernetes'
            vars: Additional terraform variables

        Yields:
            Terraform plan output lines
        """
        tf_dir = self._get_provider_dir(provider, orchestration)

        # Build command
        command = ["terraform", "plan", "-no-color", "-out=tfplan"]

        # Add server names
        server_names_json = json.dumps(server_names)
        command.extend(["-var", f"server_names={server_names_json}"])

        # Add additional variables
        if vars:
            for key, value in vars.items():
                if isinstance(value, (list, dict)):
                    value = json.dumps(value)
                command.extend(["-var", f"{key}={value}"])

        async for line in self._run_command(command, tf_dir):
            yield line

    async def apply(
        self,
        provider: str,
        orchestration: str = "swarm"
    ) -> AsyncIterator[str]:
        """
        Apply the Terraform plan

        Args:
            provider: 'aws' or 'azure'
            orchestration: 'swarm' or 'kubernetes'

        Yields:
            Terraform apply output lines
        """
        tf_dir = self._get_provider_dir(provider, orchestration)

        command = ["terraform", "apply", "-no-color", "-auto-approve", "tfplan"]

        async for line in self._run_command(command, tf_dir):
            yield line

    async def destroy(
        self,
        provider: str,
        server_names: list[str],
        orchestration: str = "swarm"
    ) -> AsyncIterator[str]:
        """
        Destroy Terraform-managed infrastructure

        Args:
            provider: 'aws' or 'azure'
            server_names: List of server instance names
            orchestration: 'swarm' or 'kubernetes'

        Yields:
            Terraform destroy output lines
        """
        tf_dir = self._get_provider_dir(provider, orchestration)

        command = ["terraform", "destroy", "-no-color", "-auto-approve"]

        # Add server names
        server_names_json = json.dumps(server_names)
        command.extend(["-var", f"server_names={server_names_json}"])

        async for line in self._run_command(command, tf_dir):
            yield line

    async def get_outputs(
        self,
        provider: str,
        orchestration: str = "swarm"
    ) -> Dict[str, Any]:
        """
        Get Terraform outputs as JSON

        Args:
            provider: 'aws' or 'azure'
            orchestration: 'swarm' or 'kubernetes'

        Returns:
            Dictionary of terraform outputs
        """
        tf_dir = self._get_provider_dir(provider, orchestration)

        command = ["terraform", "output", "-json"]

        # Run command and collect all output
        output_lines = []
        async for line in self._run_command(command, tf_dir):
            output_lines.append(line)

        # Parse JSON output
        output_json = '\n'.join(output_lines)
        return json.loads(output_json) if output_json else {}

    async def deploy_full(
        self,
        provider: str,
        server_names: list[str],
        orchestration: str = "swarm",
        vars: Optional[Dict[str, Any]] = None
    ) -> AsyncIterator[Dict[str, Any]]:
        """
        Full deployment: init -> plan -> apply -> outputs

        Args:
            provider: 'aws' or 'azure'
            server_names: List of server instance names
            orchestration: 'swarm' or 'kubernetes'
            vars: Additional terraform variables

        Yields:
            Status updates with progress information
        """
        try:
            # Step 1: Init
            yield {
                "status": TerraformStatus.INITIALIZING.value,
                "message": "Initializing Terraform...",
                "logs": []
            }

            init_logs = []
            async for line in self.init(provider, orchestration):
                init_logs.append(line)
                yield {
                    "status": TerraformStatus.INITIALIZING.value,
                    "message": line,
                    "logs": init_logs
                }

            # Step 2: Plan
            yield {
                "status": TerraformStatus.PLANNING.value,
                "message": "Creating execution plan...",
                "logs": []
            }

            plan_logs = []
            async for line in self.plan(provider, server_names, orchestration, vars):
                plan_logs.append(line)
                yield {
                    "status": TerraformStatus.PLANNING.value,
                    "message": line,
                    "logs": plan_logs
                }

            # Step 3: Apply
            yield {
                "status": TerraformStatus.APPLYING.value,
                "message": "Applying infrastructure changes...",
                "logs": []
            }

            apply_logs = []
            async for line in self.apply(provider, orchestration):
                apply_logs.append(line)
                yield {
                    "status": TerraformStatus.APPLYING.value,
                    "message": line,
                    "logs": apply_logs
                }

            # Step 4: Get outputs
            outputs = await self.get_outputs(provider, orchestration)

            yield {
                "status": TerraformStatus.SUCCESS.value,
                "message": "Infrastructure deployed successfully",
                "outputs": outputs,
                "logs": []
            }

        except Exception as e:
            yield {
                "status": TerraformStatus.ERROR.value,
                "message": f"Deployment failed: {str(e)}",
                "error": str(e),
                "logs": []
            }

    def extract_instance_ips(self, outputs: Dict[str, Any]) -> Dict[str, str]:
        """
        Extract instance IPs from Terraform outputs

        Args:
            outputs: Terraform outputs dictionary

        Returns:
            Dictionary mapping instance names to IP addresses
        """
        ips = {}

        # Handle AWS outputs
        if "instance_public_ips" in outputs:
            ips_output = outputs["instance_public_ips"]
            if isinstance(ips_output, dict) and "value" in ips_output:
                ips = ips_output["value"]

        # Handle Azure outputs
        elif "vm_public_ips" in outputs:
            ips_output = outputs["vm_public_ips"]
            if isinstance(ips_output, dict) and "value" in ips_output:
                ips = ips_output["value"]

        return ips
