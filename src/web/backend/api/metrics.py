"""
Endpoint para métricas Prometheus
"""
from fastapi import APIRouter, Response
from web.backend.services.metrics import metrics_service, CONTENT_TYPE_LATEST

router = APIRouter(prefix="/metrics", tags=["metrics"])

@router.get("")
async def get_metrics():
    """
    Endpoint de métricas Prometheus
    """
    metrics_data = metrics_service.get_metrics()
    return Response(content=metrics_data, media_type=CONTENT_TYPE_LATEST)
