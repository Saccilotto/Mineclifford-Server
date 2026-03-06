# Architecture

## System Overview

Mineclifford has two main entry points: a **web dashboard** for browser-based management, and a **CLI script** (`minecraft-ops.sh`) for terminal-based operations. Both drive the same underlying infrastructure pipeline.

```text
                     ┌─────────────────────────┐
                     │    User Entry Points     │
                     │  ┌─────────┐ ┌────────┐ │
                     │  │   Web   │ │  CLI   │ │
                     │  │Dashboard│ │ Script │ │
                     │  └────┬────┘ └───┬────┘ │
                     └───────┼──────────┼──────┘
                             │          │
                    ┌────────▼──────────▼────────┐
                    │    Deployment Pipeline      │
                    │                             │
                    │  1. Terraform (provision)   │
                    │  2. Ansible (configure)     │
                    │     OR kubectl (k8s)        │
                    │  3. Docker (run servers)    │
                    └──────────┬─────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
      ┌───────▼──────┐ ┌──────▼──────┐ ┌───────▼──────┐
      │   AWS (EC2   │ │ Azure (VMs  │ │   Local      │
      │   or EKS)    │ │  or AKS)    │ │   Docker     │
      └──────────────┘ └─────────────┘ └──────────────┘
```

## Component Status

| Component | Status | Notes |
| --------- | ------ | ----- |
| CLI (`minecraft-ops.sh`) | Active | Primary deployment tool |
| Web Dashboard | On standby | Fully built but not actively tested against current infra changes |
| Terraform (AWS/Azure) | Active | Recently updated resource configs and variable integration |
| Ansible + Docker Swarm | Active | Primary orchestration method |
| Kubernetes (EKS/AKS) | On standby | Manifests defined; tests removed in recent refactor |
| Helm Charts | On standby | Available as alternative to Kustomize |
| Cloudflare DNS/SSL | Active | Full TLS stack with Traefik integration |
| Monitoring (Prometheus/Grafana) | On standby | Defined in Swarm stack; disabled in Ansible playbook |

## Directory Structure

```text
mineclifford/
├── minecraft-ops.sh              # Main CLI operations script
├── docker-compose.yml            # Generated at runtime for local deploys
├── docker-compose.web.yml        # Web dashboard (dev)
├── docker-compose.traefik.yml    # Web dashboard (production with SSL)
├── .env.example                  # Environment variable template
│
├── src/web/                      # Web dashboard (on standby)
│   ├── backend/                  # FastAPI backend (REST + WebSocket)
│   └── frontend/                 # Vanilla JS + Tailwind CSS
│
├── terraform/                    # Infrastructure as Code
│   ├── aws/                      # EC2 + VPC + security groups
│   │   └── kubernetes/           # EKS cluster + VPC + IAM
│   ├── azure/                    # VMs + VNet + resource groups
│   │   └── kubernetes/           # AKS cluster + VNet + logging
│   ├── cloudflare/               # DNS, SSL, security rules
│   └── modules/common/           # Shared modules (SSH keys, security rules, inventory)
│
├── deployment/
│   ├── ansible/                  # Ansible playbooks (swarm_setup.yml)
│   ├── swarm/                    # Docker Swarm stack templates
│   ├── kubernetes/               # Kustomize base + AWS/Azure overlays
│   └── helm/                     # Helm charts (alternative to Kustomize)
│
├── docker/web/                   # Dockerfiles and Nginx configs
├── scripts/                      # Utility scripts
├── tests/                        # Test suite
└── docs/                         # This documentation
```

## Variable Flow

Configuration flows from the CLI through three layers:

### 1. minecraft-ops.sh to Terraform

Infrastructure variables (`PROJECT_NAME`, `ENVIRONMENT`, `OWNER`, `REGION`, `INSTANCE_TYPE`, `DISK_SIZE_GB`, `SERVER_NAMES`) are exported as `TF_VAR_*` environment variables before `terraform plan`. See [CLI-REFERENCE.md](CLI-REFERENCE.md) for the full mapping.

### 2. minecraft-ops.sh to Ansible

Application variables (`MINECRAFT_VERSION`, `MEMORY`, `MINECRAFT_MODE`, `MINECRAFT_DIFFICULTY`, `SERVER_NAMES`, `SINGLE_NODE_SWARM`) are written to `deployment/ansible/minecraft_vars.yml` at deploy time and passed via `ansible-playbook -e @minecraft_vars.yml`.

### 3. minecraft-ops.sh to Kubernetes

For Kubernetes deployments, the script applies manifests directly with `kubectl apply -k` or `kubectl apply -f`. The `NAMESPACE` variable controls the target namespace. Note: Kubernetes manifest values (memory limits, game settings) are currently **hardcoded** in YAML files and do not dynamically receive script variables.

## Tagging Strategy

All Terraform-managed resources receive a consistent set of tags:

| Tag | Source | Default |
| --- | ------ | ------- |
| `Project` | `--project-name` | `mineclifford` |
| `Environment` | `--environment` | `production` |
| `ManagedBy` | constant | `terraform` |
| `Owner` | `--owner` | `minecraft` |

For Kubernetes modules, these are passed as `TF_VAR_tags` (JSON map). For standalone modules (EC2/VM), they are set via `common_tags` locals that reference individual variables.

## Web Dashboard (On Standby)

The web dashboard is a fully built FastAPI + vanilla JS application that provides:

- Real-time server management via browser
- Live Minecraft console streaming (WebSocket)
- Cloud deployment progress tracking
- One-click server creation for Local, AWS, or Azure

**Current status**: The dashboard code exists and is structurally complete, but it has not been actively tested against recent infrastructure changes (variable integration, resource config updates). The CLI script (`minecraft-ops.sh`) is the primary and tested deployment interface.

To run the dashboard locally:

```bash
docker compose -f docker-compose.web.yml up -d
# Access at http://localhost
```

For production with SSL:

```bash
docker compose -f docker-compose.traefik.yml up -d
# Access at https://yourdomain.com
```
