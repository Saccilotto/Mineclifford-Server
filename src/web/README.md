# Mineclifford Web

**Full-stack web dashboard for managing Minecraft servers with Docker.**

## ✅ All Phases Complete

- ✅ Backend API (FastAPI + SQLite)
- ✅ Frontend UI (Vanilla JS + Tailwind)
- ✅ Docker Setup (3 services + Nginx proxy)
- ✅ Full Integration (Real containers + WebSocket console)

## Quick Start

```bash
# Start everything
docker compose -f docker-compose.web.yml up -d

# Access at http://localhost
# API docs at http://localhost/docs
```

## Features

### Dashboard

- Create/manage Minecraft servers via web UI
- Real-time status updates (auto-refresh every 5s)
- Start/Stop/Restart servers
- Live console with WebSocket streaming
- Backup & restore worlds

### Backend

- Automatic Docker container creation
- Multiple server types: Paper, Vanilla, Spigot, Forge, Fabric
- REST API + WebSocket console
- SQLite database
- Health checks

### Docker

- 3 services: backend (FastAPI), frontend (Nginx), redis (cache)
- Nginx reverse proxy + WebSocket support
- Auto port mapping for Minecraft servers
- Persistent volumes for data

## Architecture

```plaintext
Nginx (port 80)
  ├─> Frontend (static files)
  └─> Backend API (FastAPI :8000)
        ├─> SQLite database
        ├─> Docker API (creates Minecraft containers)
        └─> Redis (future caching)
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
# Create server
curl -X POST http://localhost/api/servers/ \
  -H "Content-Type: application/json" \
  -d '{"name":"my-server","server_type":"paper","version":"1.20.1","provider":"local"}'

# List servers
curl http://localhost/api/servers/

# Create backup
curl -X POST http://localhost/api/servers/{id}/backup

# Console WebSocket
ws://localhost/api/console/{id}
```

## Files

```plaintext
src/web/
├── backend/
│   ├── main.py                    # FastAPI app
│   ├── api/                       # API routes
│   │   ├── servers.py             # Server management + WebSocket
│   │   └── versions.py            # Version Manager integration
│   ├── models/server.py           # Pydantic models
│   └── services/
│       ├── docker.py              # Docker API client (httpx)
│       └── deployment.py          # Local/cloud deployment
├── frontend/
│   ├── index.html                 # Dashboard
│   └── js/                        # API client, dashboard logic, console
└── README.md

docker/web/
├── Dockerfile                     # Backend image
└── nginx.conf                     # Nginx proxy config

docker-compose.web.yml             # Full stack orchestration
```

## Requirements

- Docker + Docker Compose
- Python 3.10+ (for local dev)
- Access to `/var/run/docker.sock`

## Dependencies

```plaintext
fastapi==0.104.1
uvicorn[standard]==0.24.0
httpx==0.25.2
aiosqlite==0.19.0
pydantic==2.5.0
```

## Notes

- **Docker Socket**: Backend needs `/var/run/docker.sock` access
- **Ports**: Servers get random ports (32768+) mapped automatically
- **Volumes**: Server data persists in Docker named volumes
- **Provider**: Set `"provider":"local"` for Docker, `"aws"/"azure"` for future cloud support
