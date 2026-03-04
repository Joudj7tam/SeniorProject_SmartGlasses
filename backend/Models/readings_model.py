from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class ReadingModel(BaseModel):
    deviceId: str
    
    user_id: Optional[str] = None # main account id
    form_id: Optional[str] = None # eye health form id 
    
    timestamp: Optional[datetime] = None
    data: Dict[str, Any]
