from fastapi import APIRouter
from datetime import datetime
from typing import Optional
from Models.chart_metrics_model import ChartMetricsModel
from Controllers.chart_metrics_controller import (
    create_chart_metric,
    get_blue_light_scatter,
    get_blink_by_time,
    parse_selected_date
)


router = APIRouter()


@router.post("/add")
async def add_chart_metric(metric: ChartMetricsModel):
    return await create_chart_metric(metric)



# ---------------------------------------------------------
# Get Blue Light Scatter chart data
# ---------------------------------------------------------
@router.get("/blue-light-scatter")
async def fetch_blue_light_scatter(
    user_id: str,
    form_id: str,
    range_type: str,
    selected_date: str | None = None,
):
    parsed_date = parse_selected_date(selected_date)
    return await get_blue_light_scatter(user_id, form_id, range_type, parsed_date)

# ---------------------------------------------------------
# Get Blink By Time chart data  
# example:
# /api/chart-metrics/blink-by-time?user_id=...&form_id=...&selected_date=2026-03-08T00:00:00
# ---------------------------------------------------------
@router.get("/blink-by-time")
async def fetch_blink_by_time(
    user_id: str,
    form_id: str,
    selected_date: str | None = None,
):
    parsed_date = parse_selected_date(selected_date)
    return await get_blink_by_time(user_id, form_id, parsed_date)