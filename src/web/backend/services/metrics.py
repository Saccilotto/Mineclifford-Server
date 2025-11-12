"""
Serviço de métricas Prometheus para monitoramento
"""
from prometheus_client import Counter, Gauge, Histogram, Info, generate_latest, CONTENT_TYPE_LATEST
from prometheus_client import REGISTRY
import asyncio
import aiosqlite

# Informações da aplicação
app_info = Info('mineclifford_app', 'Mineclifford application info')
app_info.info({'version': '2.0.0', 'name': 'Mineclifford'})

# Contadores de requisições
http_requests_total = Counter(
    'mineclifford_http_requests_total',
    'Total de requisições HTTP',
    ['method', 'endpoint', 'status']
)

# Contadores de operações de servidor
server_operations = Counter(
    'mineclifford_server_operations_total',
    'Total de operações de servidor',
    ['operation', 'status']
)

# Contadores de backups
backup_operations = Counter(
    'mineclifford_backup_operations_total',
    'Total de operações de backup',
    ['operation', 'status']
)

# Gauge para servidores por status
servers_by_status = Gauge(
    'mineclifford_servers_by_status',
    'Número de servidores por status',
    ['status']
)

# Gauge para containers ativos
active_containers = Gauge(
    'mineclifford_active_containers',
    'Número de containers Docker ativos'
)

# Gauge para uso de recursos de containers
container_memory_usage = Gauge(
    'mineclifford_container_memory_bytes',
    'Uso de memória por container',
    ['server_id', 'server_name']
)

container_cpu_usage = Gauge(
    'mineclifford_container_cpu_percent',
    'Uso de CPU por container (%)',
    ['server_id', 'server_name']
)

# Histogram para latência de deployment
deployment_duration = Histogram(
    'mineclifford_deployment_duration_seconds',
    'Duração de deployment de servidores',
    ['provider']
)

# Histogram para latência de backup
backup_duration = Histogram(
    'mineclifford_backup_duration_seconds',
    'Duração de operações de backup'
)

class MetricsService:
    def __init__(self):
        self.db_path = None
        self.docker_service = None
        self.update_task = None
        self.running = False

    async def start(self):
        """Inicia coleta periódica de métricas"""
        if self.running:
            return

        from web.backend.database import DB_PATH
        from web.backend.services.docker import DockerService

        self.db_path = str(DB_PATH)
        self.docker_service = DockerService()
        self.running = True

        # Atualiza métricas periodicamente (a cada 30 segundos)
        self.update_task = asyncio.create_task(self._update_metrics_loop())
        print("Metrics service started")

    async def stop(self):
        """Para a coleta de métricas"""
        self.running = False
        if self.update_task:
            self.update_task.cancel()
            try:
                await self.update_task
            except asyncio.CancelledError:
                pass
        print("Metrics service stopped")

    async def _update_metrics_loop(self):
        """Loop para atualizar métricas periodicamente"""
        while self.running:
            try:
                await self._update_server_metrics()
                await self._update_container_metrics()
            except Exception as e:
                print(f"Error updating metrics: {e}")

            await asyncio.sleep(30)  # Atualiza a cada 30 segundos

    async def _update_server_metrics(self):
        """Atualiza métricas de servidores"""
        try:
            async with aiosqlite.connect(self.db_path) as db:
                # Conta servidores por status
                cursor = await db.execute("""
                    SELECT status, COUNT(*) as count
                    FROM servers
                    GROUP BY status
                """)
                rows = await cursor.fetchall()

                # Zera todas as métricas primeiro
                for status in ['creating', 'running', 'stopped', 'error']:
                    servers_by_status.labels(status=status).set(0)

                # Atualiza com valores reais
                for row in rows:
                    status, count = row
                    servers_by_status.labels(status=status).set(count)

        except Exception as e:
            print(f"Error updating server metrics: {e}")

    async def _update_container_metrics(self):
        """Atualiza métricas de containers Docker"""
        try:
            if not self.docker_service or not self.docker_service.available:
                return

            # Lista containers ativos
            containers = await self.docker_service.list_containers(all=False)
            active_containers.set(len(containers))

            # Para cada container, coleta estatísticas de recursos
            for container in containers:
                container_id = container['id']

                try:
                    # Obtém estatísticas do container
                    response = self.docker_service.client.get(f"/containers/{container_id}/stats?stream=false")

                    if response.status_code == 200:
                        stats = response.json()

                        # Extrai métricas de memória
                        memory_stats = stats.get('memory_stats', {})
                        memory_usage = memory_stats.get('usage', 0)

                        # Extrai métricas de CPU (cálculo simplificado)
                        cpu_stats = stats.get('cpu_stats', {})
                        precpu_stats = stats.get('precpu_stats', {})

                        cpu_delta = cpu_stats.get('cpu_usage', {}).get('total_usage', 0) - \
                                    precpu_stats.get('cpu_usage', {}).get('total_usage', 0)
                        system_delta = cpu_stats.get('system_cpu_usage', 0) - \
                                       precpu_stats.get('system_cpu_usage', 0)

                        cpu_percent = 0.0
                        if system_delta > 0 and cpu_delta > 0:
                            cpu_count = cpu_stats.get('online_cpus', 1)
                            cpu_percent = (cpu_delta / system_delta) * cpu_count * 100.0

                        # Usa o nome do container como label
                        server_name = container['name']
                        server_id = container_id

                        container_memory_usage.labels(
                            server_id=server_id,
                            server_name=server_name
                        ).set(memory_usage)

                        container_cpu_usage.labels(
                            server_id=server_id,
                            server_name=server_name
                        ).set(cpu_percent)

                except Exception as e:
                    print(f"Error collecting stats for container {container_id}: {e}")

        except Exception as e:
            print(f"Error updating container metrics: {e}")

    def get_metrics(self) -> bytes:
        """Retorna métricas no formato Prometheus"""
        return generate_latest(REGISTRY)


# Instância global do serviço de métricas
metrics_service = MetricsService()
