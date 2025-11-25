from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class NotificationModel(BaseModel):
    userId: str
    title: str
    message: str
    metric_name: str
    critical_value: float
    created_at: Optional[datetime] = datetime.utcnow()
    updated_at: Optional[datetime] = datetime.utcnow()
