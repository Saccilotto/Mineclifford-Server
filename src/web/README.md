# Mineclifford Web

## ✓ Fase 1 - Backend API - COMPLETO

## ✓ Fase 2 - Frontend UI - COMPLETO

Interface web completa para gerenciamento de servidores Minecraft.

## Quick Start

```bash
# 1. Criar ambiente virtual e instalar dependências
python3 -m venv venv
./venv/bin/pip install -r src/web/backend/requirements.txt
./venv/bin/pip install aiohttp

# 2. Terminal 1 - Iniciar backend
cd src/web/backend
../../../venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# 3. Terminal 2 - Iniciar frontend
cd src/web/frontend
python3 -m http.server 3000

# 4. Acessar dashboard
# Abra: http://localhost:3000
```

## Estrutura

```plaintext
src/web/
├── backend/
│   ├── main.py              # FastAPI app principal
│   ├── config.py            # Configurações
│   ├── database.py          # SQLite com aiosqlite
│   ├── requirements.txt     # Dependências Python
│   ├── api/
│   │   ├── versions.py      # Endpoints de versões (integrado com Version Manager)
│   │   ├── servers.py       # CRUD de servidores + WebSocket
│   │   └── monitoring.py    # Métricas
│   ├── models/
│   │   └── server.py        # Models Pydantic
│   └── services/
│       ├── deployment.py    # Integração Terraform/Ansible
│       └── docker.py        # Gerenciamento Docker
└── frontend/                # ✓ Completo
    ├── index.html           # Dashboard principal
    ├── js/
    │   ├── api.js           # Cliente HTTP
    │   ├── dashboard.js     # Lógica UI
    │   └── console.js       # Terminal xterm.js
    └── css/
        └── style.css        # Estilos customizados
```

## Instalação

### 1. Criar ambiente virtual

```bash
python3 -m venv venv
```

### 2. Instalar dependências

```bash
./venv/bin/pip install -r src/web/backend/requirements.txt
./venv/bin/pip install aiohttp  # Para o Version Manager
```

## Executar a Aplicação Completa

### 1. Iniciar Backend

```bash
cd src/web/backend
../../../venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

O servidor estará disponível em: <http://localhost:8000>

Documentação interativa: <http://localhost:8000/docs>

### 2. Iniciar Frontend

Em outro terminal:

```bash
cd src/web/frontend
python3 -m http.server 3000
```

Acesse o dashboard em: **http://localhost:3000**

### Interface Web

A interface permite:

- Visualizar estatísticas dos servidores (total, running, stopped, creating)
- Listar todos os servidores com status em tempo real
- Criar novos servidores via modal
- Iniciar/Parar/Reiniciar servidores
- Acessar console do servidor (WebSocket)
- Deletar servidores

Auto-refresh a cada 5 segundos para atualizar status.

## Endpoints Implementados

### Health Check

```bash
curl http://localhost:8000/api/health
```

### Versões

```bash
# Lista tipos de servidor
curl http://localhost:8000/api/versions/types

# Lista versões de um tipo (ex: paper)
curl "http://localhost:8000/api/versions/paper?limit=5"

# Obtém última versão
curl http://localhost:8000/api/versions/paper/latest
```

### Servidores

```bash
# Listar servidores
curl http://localhost:8000/api/servers/

# Criar servidor
curl -X POST http://localhost:8000/api/servers/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-server",
    "server_type": "paper",
    "version": "1.20.1",
    "memory": "2G",
    "max_players": 20
  }'

# Obter detalhes
curl http://localhost:8000/api/servers/{id}

# Iniciar servidor
curl -X POST http://localhost:8000/api/servers/{id}/start

# Parar servidor
curl -X POST http://localhost:8000/api/servers/{id}/stop

# Reiniciar servidor
curl -X POST http://localhost:8000/api/servers/{id}/restart

# Deletar servidor
curl -X DELETE http://localhost:8000/api/servers/{id}
```

### WebSocket Console

```bash
# WebSocket para console em tempo real
ws://localhost:8000/api/console/{id}
```

## Database

SQLite database localizado em: `data/mineclifford.db`

### Tabelas

- **servers**: Armazena servidores criados
- **deployments**: Histórico de deploys

## Testes Executados ✓

### Backend

- [x] Health check
- [x] Lista tipos de servidor
- [x] Lista versões (integração com Version Manager)
- [x] Criar servidor
- [x] Listar servidores
- [x] Obter detalhes do servidor
- [x] Iniciar servidor
- [x] Parar servidor
- [x] Deletar servidor

### Frontend

- [x] Interface HTML com Tailwind CSS
- [x] Dashboard responsivo
- [x] Modal de criação de servidor
- [x] Listagem de servidores com auto-refresh
- [x] Estatísticas em tempo real
- [x] Ações de servidor (start/stop/restart/delete)
- [x] Integração API completa
- [x] Console terminal com xterm.js (estrutura pronta)
- [x] Notificações toast
- [x] Tratamento de erros

## Próximos Passos - Fase 3 & 4

### Fase 3 - Docker Setup

1. Criar Dockerfile para backend
2. Criar docker-compose.web.yml
3. Configurar volumes de desenvolvimento
4. Adicionar Redis para cache
5. Nginx para servir frontend

### Fase 4 - Integração Completa

1. Implementar DeploymentService real (Terraform/Ansible)
2. Implementar DockerService para containers locais
3. WebSocket console com logs reais
4. Métricas do Prometheus no dashboard
5. Backup/restore automático

## Notas

- O endpoint de versões pode retornar 403 da API do PaperMC devido a rate limiting, isso é esperado
- Start/Stop de servidores atualmente apenas atualiza status no banco (implementação Docker/Terraform pendente)
- WebSocket console implementado mas precisa integração com logs do container
- Database é criado automaticamente no primeiro startup

## Dependências

- FastAPI 0.104.1
- Uvicorn 0.24.0 (com extras: httptools, uvloop, watchfiles)
- Pydantic 2.5.0
- aiosqlite 0.19.0
- Docker SDK 7.0.0
- Redis 5.0.1 (para uso futuro)
- aiohttp (para Version Manager)
