"""
user_model.py

Purpose:
    Pydantic model that defines the schema of application users.

Notes:
    - Authentication is handled by Firebase
    - Passwords are NOT stored here
"""

from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import List, Optional


class UserModel(BaseModel):
    firebase_uid: str
    email: EmailStr
    phone: Optional[str] = None
    main_form_id: Optional[str] = None
    created_at: Optional[datetime] = datetime.utcnow()
    updated_at: Optional[datetime] = datetime.utcnow()
