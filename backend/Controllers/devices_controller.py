from fastapi import HTTPException
from database import db
from datetime import datetime
from Models.devices_model import DevicesModel


# --------------------------------------------------
# Add new device to a specific user + form
# Device is reserved for this form, but not linked yet
# --------------------------------------------------
async def add_device(payload: DevicesModel):
    now = datetime.utcnow()

    if not payload.deviceId or not payload.user_id or not payload.form_id:
        raise HTTPException(status_code=400, detail="deviceId, user_id, and form_id are required")

    existing = await db["devices"].find_one({"deviceId": payload.deviceId})
    if existing:
        raise HTTPException(status_code=400, detail="Device already exists")

    device_doc = {
        "deviceId": payload.deviceId,
        "device_name": payload.device_name,
        "user_id": payload.user_id,
        "form_id": payload.form_id,
        "is_linked": False,
        "power": False,
        "errorLock": False,
        "created_at": now,
        "updated_at": now,
    }

    result = await db["devices"].insert_one(device_doc)
    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error adding device")

    device_doc["id"] = str(result.inserted_id)
    device_doc.pop("_id", None)

    return {
        "success": True,
        "message": "Device added successfully",
        "data": device_doc
    }


# --------------------------------------------------
# Get all devices for a specific user + form
# --------------------------------------------------
async def get_devices_by_user_and_form(user_id: str, form_id: str):
    devices = []

    cursor = db["devices"].find(
        {"user_id": user_id, "form_id": form_id},
        {"_id": 0}
    ).sort("created_at", -1)

    async for doc in cursor:
        devices.append(doc)

    return {
        "success": True,
        "message": "Devices fetched successfully",
        "data": devices
    }


# --------------------------------------------------
# Link one device as the active device for this form
# Only one linked device is allowed per form
# --------------------------------------------------
async def link_device(deviceId: str, user_id: str, form_id: str):
    now = datetime.utcnow()

    device = await db["devices"].find_one({
        "deviceId": deviceId,
        "user_id": user_id,
        "form_id": form_id
    })

    if not device:
        raise HTTPException(status_code=404, detail="Device not found for this form")

    # unlink all devices for this same form first
    await db["devices"].update_many(
        {"user_id": user_id, "form_id": form_id},
        {
            "$set": {
                "is_linked": False,
                "power": False,
                "errorLock": False,
                "updated_at": now
            }
        }
    )

    # link selected device
    await db["devices"].update_one(
        {"deviceId": deviceId, "user_id": user_id, "form_id": form_id},
        {
            "$set": {
                "is_linked": True,
                "updated_at": now
            }
        }
    )

    return {
        "success": True,
        "message": "Device linked successfully",
        "deviceId": deviceId,
        "user_id": user_id,
        "form_id": form_id,
        "updated_at": now
    }


# --------------------------------------------------
# Unlink device without changing user_id or form_id
# --------------------------------------------------
async def unlink_device(deviceId: str, user_id: str, form_id: str):
    now = datetime.utcnow()

    device = await db["devices"].find_one({
        "deviceId": deviceId,
        "user_id": user_id,
        "form_id": form_id
    })

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    await db["devices"].update_one(
        {"deviceId": deviceId, "user_id": user_id, "form_id": form_id},
        {
            "$set": {
                "is_linked": False,
                "power": False,
                "errorLock": False,
                "updated_at": now
            }
        }
    )

    return {
        "success": True,
        "message": "Device unlinked successfully",
        "updated_at": now
    }


# --------------------------------------------------
# Get currently linked device for this form
# --------------------------------------------------
async def get_linked_device_by_user_and_form(user_id: str, form_id: str):
    device = await db["devices"].find_one(
        {"user_id": user_id, "form_id": form_id, "is_linked": True},
        {"_id": 0}
    )

    if not device:
        raise HTTPException(status_code=404, detail="No linked device found for this form")

    return {
        "success": True,
        "device": device
    }


# --------------------------------------------------
# Control power only for the linked device of this form
# --------------------------------------------------
async def control_device_power(payload: DevicesModel):
    now = datetime.utcnow()

    if payload.power is None:
        raise HTTPException(status_code=400, detail="power is required")

    result = await db["devices"].update_one(
        {
            "deviceId": payload.deviceId,
            "user_id": payload.user_id,
            "form_id": payload.form_id,
            "is_linked": True
        },
        {
            "$set": {
                "power": payload.power,
                "errorLock": False,
                "updated_at": now
            }
        }
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Linked device not found")

    return {
        "success": True,
        "power": payload.power,
        "updated_at": now
    }


# --------------------------------------------------
# Get device power status by deviceId
# --------------------------------------------------
async def get_power_status(deviceId: str):
    device = await db["devices"].find_one({"deviceId": deviceId}, {"_id": 0})

    if not device:
        return {
            "deviceId": deviceId,
            "power": False,
            "errorLock": False,
            "is_linked": False
        }

    return {
        "deviceId": deviceId,
        "power": device.get("power", False),
        "errorLock": device.get("errorLock", False),
        "is_linked": device.get("is_linked", False),
        "updated_at": device.get("updated_at")
    }
    
    
# --------------------------------------------------
# Delete device for this specific user + form
# If the device was linked, the form becomes not linked to any device
# --------------------------------------------------
async def delete_device(deviceId: str, user_id: str, form_id: str):
    device = await db["devices"].find_one({
        "deviceId": deviceId,
        "user_id": user_id,
        "form_id": form_id
    })

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    result = await db["devices"].delete_one({
        "deviceId": deviceId,
        "user_id": user_id,
        "form_id": form_id
    })

    if result.deleted_count == 0:
        raise HTTPException(status_code=500, detail="Error deleting device")

    return {
        "success": True,
        "message": "Device deleted successfully",
        "deviceId": deviceId
    }
    