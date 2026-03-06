# CLI Reference — minecraft-ops.sh

The main operations script for deploying, managing, and destroying Minecraft server infrastructure.

## Usage

```bash
./minecraft-ops.sh [ACTION] [OPTIONS]
```

## Actions

| Action | Description |
| ------ | ----------- |
| `deploy` | Deploy Minecraft infrastructure (default) |
| `destroy` | Destroy all deployed resources |
| `status` | Check status of deployed infrastructure |
| `save-state` | Save Terraform state to remote storage |
| `load-state` | Load Terraform state from remote storage |
| `backup` | Backup Minecraft worlds |
| `restore` | Restore Minecraft worlds from backup |

## Options

### Provider and Orchestration

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `-p, --provider <aws\|azure>` | Cloud provider | `aws` |
| `-o, --orchestration <swarm\|kubernetes\|local>` | Orchestration method | `swarm` |
| `-s, --skip-terraform` | Skip Terraform provisioning | `false` |
| `-k, --k8s <eks\|aks>` | Kubernetes distribution (auto-set from provider) | `eks` |

### Minecraft Configuration

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `-v, --minecraft-version VERSION` | Minecraft server version | `1.21.11` |
| `-m, --mode <survival\|creative\|adventure\|spectator>` | Game mode | `survival` |
| `-d, --difficulty <peaceful\|easy\|normal\|hard>` | Difficulty | `normal` |
| `-b, --no-bedrock` | Disable Bedrock Edition deployment | Bedrock disabled |
| `--bedrock, --use-bedrock` | Enable Bedrock Edition deployment | — |
| `-mem, --memory MEMORY` | JVM memory allocation | `2G` |
| `-w, --world-import FILE` | Import world from zip file | — |

### Mod Support

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `--server-type TYPE` | Server type: `VANILLA`, `FORGE`, `FABRIC`, `NEOFORGE`, `PAPER` | `VANILLA` |
| `--mods PROJECTS` | Comma-separated Modrinth project slugs | — |
| `--mod-deps LEVEL` | Auto-download mod dependencies: `none`, `required`, `optional` | `required` |
| `--mod-loader-version VERSION` | Specific mod loader version | latest |

See [MODS.md](MODS.md) for detailed mod deployment documentation.

### Infrastructure Configuration

These flags control Terraform resource naming, tagging, and sizing. They are exported as `TF_VAR_*` environment variables before Terraform runs.

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `--project-name NAME` | Project name for resource naming and tagging | `mineclifford` |
| `--environment ENV` | Environment tag (`production`, `staging`, `development`, `test`) | `production` |
| `--owner OWNER` | Owner tag for resources | `minecraft` |
| `--region REGION` | Cloud region (provider-aware) | `sa-east-1` (AWS) / `East US 2` (Azure) |
| `--instance-type TYPE` | VM/instance type (provider-aware) | `t3.medium` (AWS) / `Standard_B2s` (Azure) |
| `--disk-size GB` | Disk size in GB | `30` |
| `-sn, --server-names NAMES` | Comma-separated list of server names | `instance1` |

### Operational Flags

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `-n, --namespace NAMESPACE` | Kubernetes namespace | `mineclifford` |
| `-f, --force` | Force cleanup during destroy | `false` |
| `--no-interactive` | Run in non-interactive mode | `false` |
| `--no-rollback` | Disable rollback on failure | `false` |
| `--no-save-state` | Don't save Terraform state | `false` |
| `--storage-type <s3\|azure\|github>` | State storage backend | `github` |

## Variable Flow

The script exports infrastructure variables to Terraform via `TF_VAR_*` environment variables. The `export_terraform_vars` function runs before every `terraform plan/apply`.

```config
minecraft-ops.sh            Terraform
─────────────────           ─────────
PROJECT_NAME       ──────>  TF_VAR_project_name / TF_VAR_resource_group_name / TF_VAR_prefix
ENVIRONMENT        ──────>  TF_VAR_environment / TF_VAR_tags (k8s)
OWNER              ──────>  TF_VAR_owner / TF_VAR_tags (k8s)
AWS_REGION         ──────>  TF_VAR_region
AZURE_LOCATION     ──────>  TF_VAR_location
INSTANCE_TYPE      ──────>  TF_VAR_instance_type / TF_VAR_node_instance_type / TF_VAR_vm_size
DISK_SIZE_GB       ──────>  TF_VAR_disk_size_gb / TF_VAR_node_disk_size / TF_VAR_os_disk_size_gb
SERVER_NAMES       ──────>  TF_VAR_server_names
```

For Kubernetes deployments (`--orchestration kubernetes`), tags are passed as a JSON map via `TF_VAR_tags` containing `Project`, `Environment`, `ManagedBy`, and `Owner`.

## Examples

```bash
# Local development
./minecraft-ops.sh deploy --orchestration local

# AWS with Docker Swarm (defaults)
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# AWS Kubernetes with custom naming
./minecraft-ops.sh deploy --provider aws --orchestration kubernetes \
  --project-name myserver --environment staging --region us-west-2

# Azure with larger instance
./minecraft-ops.sh deploy --provider azure --orchestration swarm \
  --instance-type Standard_B4ms --disk-size 50

# Non-interactive CI deploy
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --no-interactive --no-rollback

# Destroy with forced cleanup
./minecraft-ops.sh destroy --provider aws --orchestration swarm --force

# Backup and restore
./minecraft-ops.sh backup --provider aws --orchestration swarm
./minecraft-ops.sh restore --provider aws --orchestration swarm

# Deploy with Create mod (Fabric)
./minecraft-ops.sh deploy --orchestration local \
  --server-type FABRIC --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1

# Deploy with Create mod (Forge) on AWS
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --server-type FORGE --mods "create" \
  --minecraft-version 1.20.1 --memory 4G
```

## Logging

Every run creates a timestamped log file: `minecraft_ops_YYYYMMDD_HHMMSS.log`. All stdout and stderr are captured.

## Error Handling

On failure during deployment, the script can automatically roll back:

- **Terraform failures**: runs `terraform destroy -auto-approve`
- **Ansible/Swarm failures**: removes the Docker stack from the manager node
- **Kubernetes failures**: deletes the namespace
- **Local failures**: runs `docker compose down -v`

Disable with `--no-rollback`.
