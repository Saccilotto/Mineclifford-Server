# Mineclifford

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-%23EE0000.svg?style=flat&logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Azure](https://img.shields.io/badge/Azure-%230078D4.svg?style=flat&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)

**Mineclifford** deploys and manages Minecraft servers from a single CLI command. It provisions cloud infrastructure with Terraform, configures servers with Ansible, and runs game instances in Docker containers -- on AWS, Azure, or your local machine.

One command deploys a fully operational Minecraft server with monitoring, backups, RCON management, and auto-updates. Pick your cloud, orchestration mode, and game configuration; the pipeline handles the rest.

```bash
# Local server in under a minute
./minecraft-ops.sh deploy --orchestration compose --skip-terraform

# AWS with Docker Swarm
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# Azure with Kubernetes
./minecraft-ops.sh deploy --provider azure --orchestration kubernetes

# Modded server (Create mod on Fabric)
./minecraft-ops.sh deploy --orchestration compose --skip-terraform \
  --server-type FABRIC --mods "create-fabric,fabric-api" --minecraft-version 1.20.1
```

## How It Works

```
User runs minecraft-ops.sh
         |
         v
  +--------------+     +----------------+     +------------------+
  |  Terraform   | --> |    Ansible     | --> | Docker Swarm /   |
  |  provisions  |     |  configures    |     | Compose / K8s    |
  |  cloud infra |     |  the server    |     | runs Minecraft   |
  +--------------+     +----------------+     +------------------+
   AWS EC2 / Azure VM    Docker, firewall,     Java + Bedrock
   VPC, security groups  monitoring stack      RCON, Watchtower
   Elastic IPs, SSH      world import          backups, monitoring
```

The pipeline has three stages. **Terraform** creates cloud resources (VPC, instances, security groups, Elastic IPs) and generates an Ansible inventory from the provisioned IPs. **Ansible** connects via SSH, installs Docker, initializes Swarm or Compose, deploys the Minecraft stack, and sets up automated backups. **Docker** runs the game server alongside RCON Web Admin and Watchtower for auto-updates.

For Kubernetes deployments, the pipeline replaces Ansible with `kubectl` -- Terraform provisions an EKS or AKS cluster, and Kustomize overlays apply provider-specific patches (NLB annotations for AWS, managed-premium storage for Azure).

For local deployments (`--skip-terraform`), the script generates a `docker-compose.yml` and runs everything on your machine. No cloud credentials needed.

## Features

**Multi-cloud deployment** -- AWS (EC2, EKS) and Azure (VMs, AKS) with full Terraform automation. Infrastructure variables flow from CLI flags through `TF_VAR_*` exports into resource naming, tagging, and sizing.

**Three orchestration modes** -- Docker Swarm (single or multi-node), Kubernetes (Helm charts + Kustomize overlays per provider), and Docker Compose (local or on a cloud VM).

**Mod support** -- Fabric, Forge, and NeoForge mod loaders with auto-download from Modrinth. The CLI validates mod compatibility against your Minecraft version before deployment.

**Java + Bedrock editions** -- Both server types deploy side-by-side with independent configuration. Bedrock is optional (`--bedrock` / `--no-bedrock`).

**World management** -- Import worlds from zip files (Aternos-compatible), automated daily backups with rotation (keeps last 5), and interactive restore from backup history.

**Monitoring stack** -- Prometheus + Grafana with pre-configured scrape targets, alert rules (low TPS, high memory, server down), and Node Exporter for host metrics.

**Production-ready web dashboard** (on standby) -- FastAPI backend with WebSocket console streaming, real-time deployment progress tracking, and an Nginx/Traefik frontend with Let's Encrypt SSL via Cloudflare DNS challenge.

**Version Manager CLI** -- Python async tool (`mineclifford-version`) for querying, validating, and comparing Minecraft server versions across Paper, Vanilla, Spigot, Forge, and Fabric.

**Terraform state management** -- Save/load state to S3, Azure Blob Storage, or a dedicated GitHub branch. Prevents duplicate infrastructure across machines.

## Architecture

```
                     +---------------------------+
                     |     User Entry Points     |
                     |  +----------+ +---------+ |
                     |  |   Web    | |   CLI   | |
                     |  |Dashboard | |  Script | |
                     |  +----+-----+ +----+----+ |
                     +-------|-----------+|------+
                             |            |
                    +--------v------------v--------+
                    |     Deployment Pipeline       |
                    |                               |
                    |  1. Terraform (provision)     |
                    |  2. Ansible (configure)       |
                    |     OR kubectl (k8s)          |
                    |  3. Docker (run servers)      |
                    +---------------+---------------+
                                    |
              +---------------------+---------------------+
              |                     |                     |
      +-------v--------+   +-------v--------+   +--------v-------+
      |   AWS (EC2     |   |  Azure (VMs   |   |   Local        |
      |   or EKS)      |   |   or AKS)     |   |   Docker       |
      +----------------+   +---------------+   +----------------+
```

## Quick Start

### Prerequisites

- **Docker** and **Docker Compose** (for any deployment mode)
- **Terraform** >= 1.10.0 and **Ansible** >= 2.9 (for cloud deployments)
- **kubectl** (for Kubernetes deployments)
- Cloud credentials: `aws configure` or `az login`

### Local Deployment

```bash
git clone https://github.com/Saccilotto/Mineclifford-Server.git
cd Mineclifford-Server

# Copy environment template
cp .env.example .env

# Deploy locally
./minecraft-ops.sh deploy --orchestration compose --skip-terraform
```

Connect at `localhost:25565`. RCON Web Admin at `localhost:4326`.

### Cloud Deployment (AWS)

```bash
# Configure AWS credentials
aws configure

# Deploy with Docker Swarm
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# Custom configuration
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --project-name mycraft --environment staging \
  --region us-west-2 --instance-type t3.large --disk-size 50 \
  --minecraft-version 1.21.11 --memory 3G
```

### Modded Server

```bash
# Create mod on Fabric (local)
./minecraft-ops.sh deploy --orchestration compose --skip-terraform \
  --server-type FABRIC --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1 --memory 4G

# Create mod on Forge (AWS)
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --server-type FORGE --mods "create" \
  --minecraft-version 1.20.1 --memory 4G
```

## CLI Reference

```bash
./minecraft-ops.sh [ACTION] [OPTIONS]
```

| Action | Description |
|--------|-------------|
| `deploy` | Deploy Minecraft infrastructure (default) |
| `destroy` | Tear down all deployed resources |
| `status` | Check deployed infrastructure status |
| `backup` | Backup Minecraft worlds |
| `restore` | Restore worlds from backup |
| `save-state` / `load-state` | Manage Terraform state remotely |

### Key Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--provider <aws\|azure>` | Cloud provider | `aws` |
| `--orchestration <swarm\|kubernetes\|compose>` | Orchestration mode | `swarm` |
| `--skip-terraform` | Local-only mode (no cloud) | `false` |
| `--server-type <VANILLA\|FABRIC\|FORGE\|...>` | Server type | `VANILLA` |
| `--mods "slug1,slug2"` | Modrinth mod slugs | -- |
| `--minecraft-version VERSION` | Game version | `1.21.11` |
| `--memory MEMORY` | JVM memory | `2G` |
| `--project-name NAME` | Resource naming/tagging | `mineclifford` |
| `--instance-type TYPE` | VM size | `t3.medium` / `Standard_B2s` |

See [docs/CLI-REFERENCE.md](docs/CLI-REFERENCE.md) for the full flag list and variable flow diagram.

## Project Structure

```
mineclifford/
+-- minecraft-ops.sh              # Main CLI -- single entry point
+-- terraform/
|   +-- aws/                      # EC2, VPC, EIPs, security groups
|   |   +-- kubernetes/           # EKS cluster, IAM, EBS CSI
|   +-- azure/                    # VMs, VNet, resource groups
|   |   +-- kubernetes/           # AKS cluster, VNet, logging
|   +-- cloudflare/               # DNS, SSL, security rules
|   +-- modules/common/           # SSH keys, security rules, inventory
+-- deployment/
|   +-- ansible/                  # Swarm/Compose setup playbook
|   +-- swarm/                    # Docker Swarm stack templates
|   +-- kubernetes/               # Kustomize base + provider overlays
|   +-- helm/                     # Helm charts (alternative to Kustomize)
+-- src/
|   +-- version_manager/          # Async Python version manager
|   +-- web/                      # FastAPI + JS dashboard (on standby)
+-- docker/web/                   # Dockerfiles, Nginx configs
+-- scripts/                      # State mgmt, secrets, verification
+-- docs/                         # CLI reference, architecture, guides
```

## Component Status

| Component | Status | Notes |
|-----------|--------|-------|
| CLI (`minecraft-ops.sh`) | Active | Primary deployment interface |
| Terraform (AWS/Azure) | Active | EC2, EKS, Azure VMs, AKS |
| Ansible + Docker Swarm | Active | Primary orchestration method |
| Kubernetes (EKS/AKS) | Active | Manifests defined, testing in progress |
| Cloudflare DNS/SSL | Active | Full TLS stack |
| Helm Charts | Available | Alternative to Kustomize |
| Web Dashboard | On standby | Built but not tested against latest infra |
| Monitoring (Prometheus/Grafana) | On standby | Defined in stack, disabled in playbook |

## Documentation

- **[CLI Reference](docs/CLI-REFERENCE.md)** -- Full `minecraft-ops.sh` usage, flags, and variable flow
- **[Architecture](docs/ARCHITECTURE.md)** -- System overview, component status, directory map
- **[Cloud Deployment](docs/CLOUD-DEPLOYMENT.md)** -- Step-by-step cloud deployment guide
- **[Mod Support](docs/MODS.md)** -- Fabric, Forge, NeoForge with Modrinth auto-download
- **[Web Dashboard](src/web/README.md)** -- Dashboard architecture and API
- **[Cloudflare DNS](terraform/cloudflare/README.md)** -- DNS and SSL management

## Tech Stack

| Layer | Tools |
|-------|-------|
| IaC | Terraform (AWS, Azure, Cloudflare) |
| Configuration | Ansible, Shell |
| Orchestration | Docker Swarm, Kubernetes (EKS/AKS), Docker Compose |
| Backend | FastAPI, Python (async), Go (custom Terraform providers) |
| Monitoring | Prometheus, Grafana, Node Exporter, cAdvisor |
| Networking | Traefik, Nginx, Cloudflare (DNS challenge + SSL) |
| Game Server | itzg/minecraft-server (Java), itzg/minecraft-bedrock-server |

## Contributing

Contributions welcome. Open an issue or submit a pull request.

## License

[GNU Affero General Public License v3.0](LICENSE)

## Credits

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) -- Docker images for Minecraft
- [Terraform](https://www.terraform.io/) -- Infrastructure provisioning
- [Ansible](https://www.ansible.com/) -- Configuration automation
- [FastAPI](https://fastapi.tiangolo.com/) -- Backend framework
