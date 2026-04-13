from fastapi import APIRouter
from Controllers.devices_controller import (
    add_device,
    link_device,
    unlink_device,
    delete_device,
    control_device_power,
    get_power_status,
    get_devices_by_user_and_form,
    get_linked_device_by_user_and_form,
)
from Models.devices_model import DevicesModel

router = APIRouter()


# --------- Add new device ----------
@router.post("/add")
async def add_device_route(payload: DevicesModel):
    return await add_device(payload)


# --------- Link device ----------
@router.post("/link")
async def link_device_route(deviceId: str, user_id: str, form_id: str):
    return await link_device(deviceId, user_id, form_id)


# --------- Unlink device ----------
@router.post("/unlink")
async def unlink_device_route(deviceId: str, user_id: str, form_id: str):
    return await unlink_device(deviceId, user_id, form_id)


# --------- Control linked device power ----------
@router.post("/power")
async def control_power_route(payload: DevicesModel):
    return await control_device_power(payload)


# --------- Get device power status ----------
@router.get("/power/{deviceId}")
async def get_power_route(deviceId: str):
    return await get_power_status(deviceId)


# --------- Get all devices for this user + form ----------
@router.get("/by-user-form")
async def get_devices_route(user_id: str, form_id: str):
    return await get_devices_by_user_and_form(user_id, form_id)


# --------- Get currently linked device for this user + form ----------
@router.get("/linked")
async def get_linked_device_route(user_id: str, form_id: str):
    return await get_linked_device_by_user_and_form(user_id, form_id)


# --------- Delete device ----------
@router.delete("/delete")
async def delete_device_route(deviceId: str, user_id: str, form_id: str):
    return await delete_device(deviceId, user_id, form_id)