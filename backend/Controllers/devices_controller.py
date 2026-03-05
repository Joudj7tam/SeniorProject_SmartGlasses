from fastapi import HTTPException
from database import db
from datetime import datetime
from Models.devices_model import DevicesModel

# Assign device to user/form (upsert)
async def assign_device(payload: DevicesModel):
    now = datetime.utcnow()

    if not payload.deviceId or not payload.user_id or not payload.form_id:
        raise HTTPException(status_code=400, detail="deviceId, user_id, form_id are required")

    existing = await db["devices"].find_one({"deviceId": payload.deviceId})

    if existing:
        await db["devices"].update_one(
            {"deviceId": payload.deviceId},
            {"$set": {"user_id": payload.user_id, "form_id": payload.form_id, "updated_at": now}}
        )
    else:
        await db["devices"].insert_one({
            "deviceId": payload.deviceId,
            "user_id": payload.user_id,
            "form_id": payload.form_id,
            "power": False,
            "errorLock": False,
            "created_at": now,
            "updated_at": now,
        })

    return {"success": True, "message": "Device linked successfully"}


# Control device power by user_id + form_id (same schema)
async def control_device_power(payload: DevicesModel):
    now = datetime.utcnow()

    if payload.power is None:
        raise HTTPException(status_code=400, detail="power is required")
    if not payload.user_id or not payload.form_id:
        raise HTTPException(status_code=400, detail="user_id and form_id are required")

    result = await db["devices"].update_one(
        {"user_id": payload.user_id, "form_id": payload.form_id},
        {"$set": {"power": payload.power, "errorLock": False, "updated_at": now}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Device not found")

    return {"success": True, "power": payload.power, "updated_at": now}


# Get device power status by deviceId
async def get_power_status(deviceId: str):
    device = await db["devices"].find_one({"deviceId": deviceId}, {"_id": 0})

    if not device:
        return {"deviceId": deviceId, "power": False, "errorLock": False}

    return {
        "deviceId": deviceId,
        "power": device.get("power", False),
        "errorLock": device.get("errorLock", False),
        "updated_at": device.get("updated_at")
    }


# Get device by user + form
async def get_device_by_user_and_form(user_id: str, form_id: str):
    device = await db["devices"].find_one(
        {"user_id": user_id, "form_id": form_id},
        {"_id": 0}
    )

    if not device:
        raise HTTPException(status_code=404, detail="Device not found for this user and form")

    return {"success": True, "device": device}


# Get device link info (user_id + form_id) by deviceId
async def get_device_link_by_device_id(deviceId: str):
    if not deviceId:
        raise HTTPException(status_code=400, detail="deviceId is required")

    device = await db["devices"].find_one(
        {"deviceId": deviceId},
        {"_id": 0, "deviceId": 1, "user_id": 1, "form_id": 1}
    )

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Extract user_id and form_id, return them in a clear format
    user_id = device.get("user_id")
    form_id = device.get("form_id")

    if not user_id or not form_id:
        raise HTTPException(status_code=404, detail="Device is not linked to any user/form")

    return {
        "success": True,
        "deviceId": device.get("deviceId"),
        "user_id": user_id,
        "form_id": form_id,
    }
    
    
    
# Unlink device (clear user_id + form_id) by deviceId, but only if matches current link
async def unlink_device(deviceId: str, user_id: str, form_id: str):
    now = datetime.utcnow()

    if not deviceId or not user_id or not form_id:
        raise HTTPException(status_code=400, detail="deviceId, user_id, form_id are required")

    device = await db["devices"].find_one({"deviceId": deviceId}, {"_id": 0, "user_id": 1, "form_id": 1})
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # insure that the device is currently linked to the same user_id and form_id before unlinking
    if device.get("user_id") != user_id or device.get("form_id") != form_id:
        raise HTTPException(status_code=403, detail="Device is linked to another account")

    await db["devices"].update_one(
        {"deviceId": deviceId},
        {"$set": {"user_id": None, "form_id": None, "updated_at": now}}
    )

    return {"success": True, "message": "Device unlinked successfully", "updated_at": now}