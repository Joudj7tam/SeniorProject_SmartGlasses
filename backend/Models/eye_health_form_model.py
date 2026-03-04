"""
eye_health_form_model.py

Purpose:
    Pydantic model for post-registration eye health information form.
"""

from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional


class EyeHealthFormModel(BaseModel):
    main_account_id: str  # MongoDB Parent account id (relation with the main account from Users collection)
    is_active: Optional[bool] = None # To indicate if the form is active

    # Personal information
    full_name: str
    date_of_birth: datetime
    gender: str

    # Previous eye conditions
    previous_eye_conditions: List[str]  # myopia, hyperopia, astigmatism

    # Chronic diseases
    chronic_diseases: List[str]  # diabetes, hypertension

    # Vision aids
    uses_glasses: bool
    uses_contact_lenses: bool

    # Eye surgery history
    eye_surgery_history: Optional[str] = None

    # Daily habits & lifestyle
    screen_time_hours: int
    lighting_conditions: str
    sleep_hours: int
    diet: Optional[str] = None # Healthy, Unhealthy, Avarage

    # Current eye symptoms
    current_eye_symptoms: List[str]  # dryness, redness, itching, tearing, eye strain, blurred vision
    
    smart_light_enabled: Optional[bool] = False

    created_at: Optional[datetime] = datetime.utcnow()
    updated_at: Optional[datetime] = datetime.utcnow()
