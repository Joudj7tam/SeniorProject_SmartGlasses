from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ChartMetricsModel(BaseModel):
    # IDs
    deviceId: str
    user_id: Optional[str] = None
    form_id: Optional[str] = None

    # Snapshot timestamp
    timestamp: Optional[datetime] = None

    # Blink metrics for the last 5-minute bucket
    blink_count: Optional[int] = 0
    blink_rate: Optional[float] = 0.0
    latest_ibi: Optional[float] = None
    avg_ibi: Optional[float] = None

    # Light metrics
    lux: Optional[float] = 0.0
    blue_ratio: Optional[float] = 0.0

    # Bucket info
    bucket_minutes: Optional[int] = 5

    # Timestamps for DB record
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None