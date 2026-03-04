"""
notification_model.py

Purpose:
    Pydantic model that defines the schema of notification payloads.

Maintainability notes:
    - Keep field names consistent with mobile app expectations.
"""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class NotificationModel(BaseModel):
    user_id: Optional[str] = None # main account id
    form_id: Optional[str] = None # eye health form id
    deviceId: str
    title: str
    message: str
    metric_name: str
    critical_value: float
    isRead: bool = False
    created_at: Optional[datetime] = datetime.utcnow()
    updated_at: Optional[datetime] = datetime.utcnow()
