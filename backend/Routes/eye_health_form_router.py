from fastapi import APIRouter
from Models.eye_health_form_model import EyeHealthFormModel
from fastapi import Body
from Controllers.eye_health_form_controller import (
    create_eye_health_form,
    get_eye_health_form_by_id,
    switch_forms,
    get_active_eye_health_form,
    get_all_eye_health_forms,
    get_main_eye_health_form,
    delete_eye_health_form,
    toggle_smart_light,
    get_smart_light_state,
    get_home_selected_charts,
    update_home_selected_charts,
    update_eye_health_form
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

# --------- Toggle smart light setting ---------
@router.post("/toggle-smart-light")
async def toggle_smart_light_setting(form_id: str, enabled: bool):
    return await toggle_smart_light(form_id, enabled)

# --------- Get smart light setting ---------
@router.get("/smart-light-state")
async def smart_light_state(form_id: str, main_account_id: str | None = None):
    return await get_smart_light_state(form_id=form_id, main_account_id=main_account_id)

# --------- Get selected home charts ---------
@router.get("/get-home-selected-charts")
async def get_selected_home_charts(form_id: str, main_account_id: str):
    return await get_home_selected_charts(form_id, main_account_id)


# --------- Update selected home charts ---------
@router.put("/update-home-selected-charts/{form_id}")
async def update_selected_home_charts(
    form_id: str,
    main_account_id: str,
    home_selected_charts: list[str] = Body(...)
):
    return await update_home_selected_charts(
        form_id=form_id,
        main_account_id=main_account_id,
        charts=home_selected_charts
    )

@router.put("/update/{form_id}")
async def update_form(
    form_id: str,
    main_account_id: str,
    payload: dict = Body(...)
):
    return await update_eye_health_form(form_id, main_account_id, payload)