from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class ReadingModel(BaseModel):
    deviceId: str
    timestamp: Optional[datetime] = None
    data: Dict[str, Any]
