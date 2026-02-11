from fastapi import APIRouter
from Models.eye_health_form_model import EyeHealthFormModel
from Controllers.eye_health_form_controller import (
    create_eye_health_form,
    get_eye_health_form_by_id,
    switch_forms,
    get_active_eye_health_form,
    get_all_eye_health_forms,
    get_main_eye_health_form,
    delete_eye_health_form
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


# --------- Get active eye health form for a user ---------
@router.get("/active")
async def active_form(main_account_id: str):
    return await get_active_eye_health_form(main_account_id)


# --------- Get all forms for a user ---------
@router.get("/list")
async def list_forms(main_account_id: str):
    return await get_all_eye_health_forms(main_account_id)


# --------- Get main form for a user ---------
@router.get("/main")
async def main_form(main_account_id: str):
    return await get_main_eye_health_form(main_account_id)

# --------- Delete eye health form (sub account) ---------
@router.delete("/delete")
async def delete_form(main_account_id: str, form_id: str):
    return await delete_eye_health_form(main_account_id, form_id)