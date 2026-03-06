# Cloud Deployment Guide

Deploy Minecraft servers to AWS or Azure using `minecraft-ops.sh`.

## Prerequisites

- **Terraform** >= 1.10.0
- **Ansible** >= 2.9 (for Docker Swarm deployments)
- **kubectl** (for Kubernetes deployments)
- **Cloud credentials** configured:
  - AWS: `aws configure` or environment variables
  - Azure: `az login` and set `AZURE_SUBSCRIPTION_ID` in `.env`
- **SSH key pair** at `~/.ssh/id_rsa.pub` (or override with Terraform variable)

## Quick Start

### AWS with Docker Swarm (Recommended)

```bash
# Default deployment
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# Custom configuration
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --project-name mycraft --environment staging \
  --region us-west-2 --instance-type t3.large --disk-size 50 \
  --minecraft-version 1.21.11 --memory 3G --mode survival
```

### Azure with Docker Swarm

```bash
# Requires AZURE_SUBSCRIPTION_ID in .env
./minecraft-ops.sh deploy --provider azure --orchestration swarm \
  --region "East US 2" --instance-type Standard_B2ms
```

### AWS with Kubernetes

```bash
./minecraft-ops.sh deploy --provider aws --orchestration kubernetes \
  --namespace mineclifford --project-name mycraft
```

### Docker Compose (Local)

```bash
./minecraft-ops.sh deploy --orchestration compose --skip-terraform
```

No cloud credentials needed. Creates a `docker-compose.yml` and runs containers locally.
(`--orchestration local` is kept as a backward-compatible alias.)

### Docker Compose (Cloud VM)

```bash
./minecraft-ops.sh deploy --provider aws --orchestration compose
```

Provisions cloud VM infrastructure with Terraform, then runs Docker Compose on the manager node via Ansible.

### Modded Server (any orchestration)

Add `--server-type` and `--mods` to any deploy command. See [MODS.md](MODS.md) for full details.

```bash
# Create mod on AWS Kubernetes (Fabric)
./minecraft-ops.sh deploy --provider aws --orchestration kubernetes \
  --server-type FABRIC --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1 --memory 4G

# Create mod on local Docker Compose (Forge)
./minecraft-ops.sh deploy --orchestration compose --skip-terraform \
  --server-type FORGE --mods "create" \
  --minecraft-version 1.20.1 --memory 4G
```

## What Happens During Deploy

### Step 1: Validation

The script checks for required tools, cloud credentials, and validates all parameters.

### Step 2: Terraform State (Optional)

If `--no-save-state` is not set, the script attempts to load previously saved Terraform state to prevent duplicate infrastructure.

### Step 3: Terraform Provisioning

Infrastructure variables are exported as `TF_VAR_*` environment variables. Terraform creates:

**AWS (Swarm)**:

- VPC, subnet, internet gateway, route table
- Security group (SSH, Minecraft, monitoring ports)
- EC2 instance(s) with SSH keys
- Elastic IPs

**AWS (Kubernetes)**:

- VPC with public/private subnets across AZs
- EKS cluster with managed node group
- IAM roles for EBS CSI driver
- Security group rules for Minecraft ports

**Azure (Swarm)**:

- Resource group, VNet, subnet
- Network security group
- VM(s) with public IPs and SSH keys

**Azure (Kubernetes)**:

- Resource group, VNet, subnet
- AKS cluster with auto-scaling node pool
- Log Analytics workspace

### Step 4: Configuration

**For Swarm**: Ansible connects to the provisioned instance(s), installs Docker, initializes Swarm, and deploys the Minecraft stack.

**For Kubernetes**: kubectl applies Kustomize overlays or base manifests to the cluster. World import is handled via init containers and PVCs.

### Step 5: Terraform State Save

State is saved to the configured backend (GitHub, S3, or Azure storage).

## Resource Tagging

All cloud resources are tagged consistently:

```text
Project     = <--project-name>     (default: mineclifford)
Environment = <--environment>      (default: production)
ManagedBy   = terraform
Owner       = <--owner>            (default: minecraft)
```

This enables cost tracking, resource filtering, and multi-tenant isolation.

## Operations

### Check Status

```bash
./minecraft-ops.sh status --provider aws --orchestration swarm
```

Displays running services, server logs (last 10 lines), and connection information (IP:port).

### Backup Worlds

```bash
./minecraft-ops.sh backup --provider aws --orchestration swarm
```

Creates timestamped tar.gz archives of Minecraft world data. For Swarm, this runs a backup script on the remote manager node and downloads the result. Keeps the last 5 backups.

### Restore Worlds

```bash
./minecraft-ops.sh restore --provider aws --orchestration swarm
```

Lists available backups and prompts for selection (use `--no-interactive` for latest). Stops services, replaces world data, and restarts.

### Import World

```bash
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --world-import /path/to/world.zip
```

Extracts the zip, creates a tar.gz, and injects it during deployment via Ansible (Swarm) or init containers (Kubernetes).

### Destroy Infrastructure

```bash
# Interactive confirmation
./minecraft-ops.sh destroy --provider aws --orchestration swarm

# Skip confirmation
./minecraft-ops.sh destroy --provider aws --orchestration swarm --force
```

Removes the Docker stack (or Kubernetes namespace), then runs `terraform destroy`. The `verify-destruction.sh` script checks for orphaned resources.

## CI/Non-Interactive Mode

```bash
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --no-interactive --no-rollback --no-save-state
```

Suitable for CI pipelines. Skips all confirmation prompts, disables automatic rollback, and skips remote state management.

## Troubleshooting

### Logs

Every run creates `minecraft_ops_YYYYMMDD_HHMMSS.log` in the project root.

### Terraform State Conflicts

If Terraform detects existing resources that weren't provisioned by the current state:

```bash
# Load saved state first
./minecraft-ops.sh load-state --provider aws --storage-type github

# Then deploy
./minecraft-ops.sh deploy --provider aws --orchestration swarm
```

### SSH Connection Issues

The script uses `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null` for SSH. If Ansible fails to connect, wait a minute for the instance to fully initialize and retry with `--skip-terraform`.

### Kubernetes Not Responding

For EKS, ensure `eksctl` is installed and AWS credentials have EKS permissions. For AKS, ensure `az aks` commands work. Run `kubectl get nodes` to verify cluster access before deploying.
