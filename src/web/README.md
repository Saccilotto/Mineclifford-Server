# Mineclifford Web Dashboard

Full-stack web dashboard for managing Minecraft servers locally and in the cloud.

## Status

- Backend API (FastAPI + SQLite)
- Frontend UI (Vanilla JS + Tailwind)
- Docker Setup (3 services + Nginx proxy)
- Full Integration (Real containers + WebSocket console)
- Cloud Deployment (Terraform + Ansible automation)

## Quick Start

```bash
# Start everything
docker compose -f docker-compose.web.yml up -d

# Access at http://localhost
# API docs at http://localhost/docs
```

## Features

### Dashboard

- Server creation and management via web UI
- Real-time status monitoring (5-second refresh)
- Live console with WebSocket streaming
- Cloud deployment progress tracking

### Backend

- REST API (FastAPI) + WebSocket support
- Docker API integration for local containers
- Terraform/Ansible executors for cloud deployments
- SQLite database for server state

### Deployment Options

- **Local**: Direct Docker container creation
- **Cloud**: Automated AWS/Azure provisioning via Terraform + Ansible
- Real-time progress updates via WebSocket

## Architecture

```text
Nginx Proxy (port 80)
  ├─> Frontend (HTML/JS/Tailwind - static files)
  └─> Backend API (FastAPI :8000)
        ├─> SQLite database
        ├─> Docker API (local containers)
        ├─> Terraform executor (cloud provisioning)
        ├─> Ansible executor (cloud configuration)
        └─> WebSocket (console + deployment progress)
```

## Usage

```bash
# Docker commands
docker compose -f docker-compose.web.yml up -d     # Start
docker compose -f docker-compose.web.yml logs -f   # Logs
docker compose -f docker-compose.web.yml down      # Stop

# Development mode (without Docker)
cd src/web/backend && ../../../venv/bin/uvicorn main:app --reload  # Terminal 1
cd src/web/frontend && python3 -m http.server 3000                 # Terminal 2
```

## API Examples

```bash
# Create local server
curl -X POST http://localhost/api/servers/ \
  -H "Content-Type: application/json" \
  -d '{"name":"my-server","server_type":"paper","version":"1.20.1","provider":"local"}'

# Create cloud server
curl -X POST http://localhost/api/servers/ \
  -H "Content-Type: application/json" \
  -d '{"name":"aws-server","server_type":"paper","provider":"aws","orchestration":"swarm"}'

# List servers
curl http://localhost/api/servers/

# WebSocket endpoints
ws://localhost/api/console/{id}              # Live console
ws://localhost/api/servers/deploy-cloud/{id} # Cloud deployment progress
```

## Directory Structure

```text
src/web/
├── backend/
│   ├── main.py                       # FastAPI app entry point
│   ├── api/
│   │   ├── servers.py                # Server CRUD + WebSocket endpoints
│   │   └── versions.py               # Version manager integration
│   ├── models/server.py              # Pydantic models
│   └── services/
│       ├── docker.py                 # Docker API client
│       ├── deployment.py             # Deployment orchestration
│       ├── terraform_executor.py     # Terraform automation
│       └── ansible_executor.py       # Ansible automation
└── frontend/
    ├── index.html                    # Dashboard UI
    └── js/
        ├── dashboard.js              # Main dashboard logic
        ├── cloud-deploy.js           # Cloud deployment UI
        └── console.js                # Live console

docker/web/
├── Dockerfile                        # Backend container
├── nginx.conf                        # Local development config
└── nginx-traefik.conf                # Production (behind Traefik)

docker-compose.web.yml                # Local development stack
```

## Requirements

- Docker and Docker Compose
- Python 3.10+ (for local development)
- Access to `/var/run/docker.sock` (for Docker API)

### Additional for Cloud Deployments

- Terraform v1.0+
- Ansible v2.9+
- Cloud provider credentials (AWS/Azure)

## Backend Dependencies

```text
fastapi==0.104.1          # Web framework
uvicorn[standard]==0.24.0 # ASGI server
httpx==0.25.2             # Async HTTP client
aiosqlite==0.19.0         # Async SQLite
pydantic==2.5.0           # Data validation
```

## Notes

- Backend requires `/var/run/docker.sock` access for container management
- Minecraft servers use auto-assigned ports (32768+)
- Server data persists in Docker named volumes
- Cloud deployments stream real-time progress via WebSocket
- SQLite database stored in `data/mineclifford.db`
