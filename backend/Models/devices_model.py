from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class DevicesModel(BaseModel):
    # Device identity
    deviceId: str
    device_name: Optional[str] = None

    # Fixed ownership to one specific form
    user_id: str
    form_id: str

    # Current link state inside the same form
    is_linked: Optional[bool] = False

    # Device state
    power: Optional[bool] = False
    errorLock: Optional[bool] = False

    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None