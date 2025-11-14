# Mineclifford

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)

## Overview

**Mineclifford** is a web-based platform for deploying and managing Minecraft servers. Deploy locally via Docker or to cloud infrastructure (AWS/Azure) with automated provisioning, monitoring, and SSL configuration.

## Features

### Web Dashboard

- **Real-time management** via browser interface
- **Live console** with WebSocket streaming
- **Server status** monitoring with auto-refresh
- **One-click deployment** to local Docker or cloud providers

### Cloud Deployment

- **Multi-cloud support**: AWS and Azure with Terraform automation
- **Orchestration options**: Docker Swarm or Kubernetes
- **Real-time progress**: Watch infrastructure provisioning and configuration via WebSocket
- **DNS management**: Cloudflare integration for automatic domain setup
- **SSL/TLS**: Let's Encrypt certificates via DNS challenge

### Server Types

- **Java Edition**: Paper, Vanilla, Spigot, Forge, Fabric
- **Bedrock Edition**: Official server support
- **Version flexibility**: Automatic version management and downloads

### Infrastructure

- **Terraform**: Automated cloud resource provisioning
- **Ansible**: Server configuration and deployment automation
- **Docker**: Containerized server instances
- **Monitoring**: Prometheus and Grafana (optional)

## Architecture

```plaintext
┌─────────────────────────────────────────────────────┐
│               Web Dashboard (Browser)               │
│  • Create/manage servers  • Live console  • Status  │
└────────────────────┬────────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │   Nginx Reverse     │
          │       Proxy         │
          └──────────┬──────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼─────────┐      ┌────────▼────────┐
│ FastAPI Backend │      │ Frontend (HTML/ │
│  • REST API     │      │  JS/Tailwind)   │
│  • WebSocket    │      └─────────────────┘
│  • Docker API   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼────────────────────┐
│Local │  │  Cloud Deployment     │
│Docker│  │  ┌─────────────────┐  │
│Servers│  │ │Terraform (IaC)  │  │
└──────┘  │  │ • AWS/Azure     │  │
          │  └────────┬────────┘  │
          │           │           │
          │  ┌────────▼────────┐  │
          │  │Ansible (Config) │  │
          │  │ • Docker Swarm  │  │
          │  │ • Kubernetes    │  │
          │  └────────┬────────┘  │
          │           │           │
          │  ┌────────▼────────┐  │
          │  │ Cloud Minecraft │  │
          │  │    Servers      │  │
          │  └─────────────────┘  │
          └───────────────────────┘
```

**Components:**

- **Web Dashboard**: Browser-based UI for server management with real-time updates
- **Backend API**: FastAPI service handling requests, Docker orchestration, and cloud deployments
- **Local Deployment**: Direct Docker container creation for development/testing
- **Cloud Deployment**: Automated Terraform → Ansible pipeline for AWS/Azure infrastructure
- **Monitoring**: Optional Prometheus/Grafana stack for metrics and dashboards

## Prerequisites

### For Local Development

- Docker and Docker Compose
- Git

### For Cloud Deployments (Optional)

- **Terraform** v1.0+ (for infrastructure provisioning)
- **Ansible** v2.9+ (for server configuration)
- **Cloud credentials**: AWS (via `aws configure`) or Azure (via `az login`)
- **SSH key pair**: For connecting to cloud instances

### For Production Deployment

- **Domain**: Managed by Cloudflare (for DNS/SSL automation)
- **Cloudflare API token**: With DNS edit permissions

## Quick Start

### Option 1: Web Dashboard (Recommended)

```bash
# Clone repository
git clone https://github.com/yourusername/mineclifford.git
cd mineclifford

# Copy environment template
cp .env.example .env

# Start web dashboard
docker compose -f docker-compose.web.yml up -d

# Access at http://localhost
# API docs at http://localhost/docs
```

Use the web interface to:

1. Click "New Server"
2. Choose provider (Local Docker, AWS, or Azure)
3. Configure server settings
4. Watch real-time deployment progress
5. Access live console when ready

### Option 2: CLI Operations

```bash
# Deploy locally for testing
./minecraft-ops.sh deploy --orchestration local

# Deploy to AWS with Docker Swarm
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# Deploy to Azure with Kubernetes
./minecraft-ops.sh deploy --provider azure --orchestration kubernetes

# Check status
./minecraft-ops.sh status --provider aws

# Destroy infrastructure
./minecraft-ops.sh destroy --provider aws
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```env
# Cloud Credentials (optional, for cloud deployments)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=us-east-2

AZURE_SUBSCRIPTION_ID=your_azure_id

# Cloudflare (for production with SSL)
CF_API_EMAIL=admin@example.com
CF_API_TOKEN=your_cloudflare_token
DOMAIN_NAME=yourdomain.com
ACME_EMAIL=admin@yourdomain.com

# Server Defaults
MINECRAFT_VERSION=latest
MINECRAFT_GAMEMODE=survival
MINECRAFT_DIFFICULTY=normal
MINECRAFT_MEMORY=2G
TZ=UTC
```

See `.env.example` for all available options.

## Monitoring (Optional)

Optional Prometheus and Grafana stack for server metrics:

- **Prometheus**: Collects server resource and Minecraft-specific metrics
- **Grafana**: Visualizes dashboards for resource usage and player activity
- **Node Exporter**: System-level metrics

Access Grafana at `http://server-ip:3000` (default: admin/admin)

## Production Deployment

Deploy with Traefik reverse proxy, SSL, and BasicAuth protection:

```bash
# 1. Setup Cloudflare DNS
cd terraform/cloudflare
terraform apply -var="platform_ip=YOUR_SERVER_IP"

# 2. Generate BasicAuth password
./scripts/generate-basicauth.sh admin YourPassword

# 3. Configure .env with credentials

# 4. Deploy platform
docker compose -f docker-compose.traefik.yml up -d
```

Access at `https://yourdomain.com` with BasicAuth credentials.

See [docs/DEPLOYMENT-TRAEFIK.md](docs/DEPLOYMENT-TRAEFIK.md) for details.

## Testing Cloud Deployment

Test the complete cloud deployment workflow locally:

```bash
# Start dashboard
docker compose -f docker-compose.web.yml up -d

# Open http://localhost and create a cloud server
# Watch real-time Terraform and Ansible progress
```

See [docs/TESTING-CLOUD-DEPLOYMENT.md](docs/TESTING-CLOUD-DEPLOYMENT.md) for detailed testing guide.

## Project Structure

```plaintext
mineclifford/
├── src/web/              # Web dashboard (FastAPI + HTML/JS)
├── terraform/            # Infrastructure as code (AWS/Azure/Cloudflare)
├── deployment/           # Ansible playbooks and Docker configs
├── docker/               # Dockerfiles and configs
├── scripts/              # Utility scripts
└── docs/                 # Documentation
```

## Documentation

- [Web Dashboard README](src/web/README.md) - Dashboard architecture and API
- [Cloudflare DNS Setup](terraform/cloudflare/README.md) - DNS management
- [Traefik Deployment](docs/DEPLOYMENT-TRAEFIK.md) - Production deployment guide
- [Testing Guide](docs/TESTING-CLOUD-DEPLOYMENT.md) - Cloud deployment testing

## Contributing

Contributions welcome! Open an issue or submit a pull request.

## License

MIT License - see [LICENSE](LICENSE) file.

## Credits

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) - Docker images
- [Terraform](https://www.terraform.io/) - Infrastructure provisioning
- [Ansible](https://www.ansible.com/) - Configuration automation
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework
