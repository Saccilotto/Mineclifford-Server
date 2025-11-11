from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api/monitoring", tags=["monitoring"])

@router.get("/metrics")
async def get_metrics():
    """Obtém métricas dos servidores"""
    # TODO: Integrar com Prometheus
    return {
        "total_servers": 0,
        "running_servers": 0,
        "stopped_servers": 0,
        "total_players": 0
    }
