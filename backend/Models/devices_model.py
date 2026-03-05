from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class DevicesModel(BaseModel):
    # IDs
    deviceId: str
    user_id: Optional[str] = None  # main account mongoDB id
    form_id: Optional[str] = None  # eye health form mongoDB id

    # State
    power: Optional[bool] = False     # Indicates if the device is ON (True) or OFF (False)
    errorLock: Optional[bool] = False    # Indicates if the device is locked due to an error (e.g., failed to turn on/off)

    # Timestamps (set in controller)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None