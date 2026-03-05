from fastapi import APIRouter
from Controllers.devices_controller import (
    assign_device,
    control_device_power,
    get_power_status,
    get_device_by_user_and_form,
    get_device_link_by_device_id,
    unlink_device
)
from Models.devices_model import DevicesModel

router = APIRouter()


# --------- Assign device ----------
@router.post("/assign")
async def assign_device_route(payload: DevicesModel):
    return await assign_device(payload)


# --------- Control device power ----------
@router.post("/power")
async def control_power_route(payload: DevicesModel):
    return await control_device_power(payload)


# --------- Get device power status ----------
@router.get("/power/{deviceId}")
async def get_power_route(deviceId: str):
    return await get_power_status(deviceId)


# --------- Get full device data by user and form ----------
@router.get("/by-user-form")
async def get_device_route(user_id: str, form_id: str):
    return await get_device_by_user_and_form(user_id, form_id)


# --------- Get linked profile id by deviceId ----------
@router.get("/link-by-device")
async def get_link_by_device_route(deviceId: str):
    return await get_device_link_by_device_id(deviceId)


# --------- Unlink device ----------
@router.post("/unlink")
async def unlink_device_route(deviceId: str, user_id: str, form_id: str):
    return await unlink_device(deviceId, user_id, form_id)