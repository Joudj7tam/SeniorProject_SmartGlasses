from fastapi import APIRouter
from Models.eye_health_form_model import EyeHealthFormModel
from Controllers.eye_health_form_controller import (
    create_eye_health_form,
    get_eye_health_form_by_id,
    switch_forms
)

router = APIRouter()


# --------- Submit eye health form ---------
@router.post("/add")
async def submit_eye_health_form(form: EyeHealthFormModel):
    return await create_eye_health_form(form)


# --------- Get eye health form by form id ---------
@router.get("/get/{form_id}")
async def get_eye_health_form(form_id: str, main_account_id: str):
    return await get_eye_health_form_by_id(form_id, main_account_id)


# --------- Switch active form ---------
@router.post("/switch")
async def switch_active_form(main_account_id: str, form_id: str):
    return await switch_forms(main_account_id, form_id)