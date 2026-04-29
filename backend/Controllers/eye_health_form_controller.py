"""
Purpose:
    Operations for eye health forms.
"""

from fastapi import HTTPException
from Models.eye_health_form_model import EyeHealthFormModel
from database import db
from datetime import datetime
from bson import ObjectId


# --------------- Create eye health form ---------------
async def create_eye_health_form(form: EyeHealthFormModel):

    # 1- validate user exists
    user = await db.users.find_one({"_id": ObjectId(form.main_account_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 2- prevent duplicate form for same user
    existing_form = await db.eye_health_forms.find_one({
        "main_account_id": ObjectId(form.main_account_id),
        "full_name": form.full_name
    })
    if existing_form:
        raise HTTPException(
            status_code=400,
            detail="Eye health form with the same full name already exists"
        )
        
    # 3- set all forms inactive first
    await db.eye_health_forms.update_many(
        {"main_account_id": ObjectId(form.main_account_id)},
        {"$set": {"is_active": False, "updated_at": datetime.utcnow()}}
    )

    form_dict = form.dict()
    now = datetime.utcnow()

    form_dict["created_at"] = now
    form_dict["updated_at"] = now
    form_dict["is_active"] = True  # make the new form active by default
    form_dict["main_account_id"] = ObjectId(form.main_account_id) # Convert to ObjectId for MongoDB storage

    # 4- insert form
    result = await db.eye_health_forms.insert_one(form_dict)
    if not result.inserted_id:
        raise HTTPException(
            status_code=500,
            detail="Error saving eye health form"
        )
        
    # 5- if this is the user's first form, set it as their main form
    if not user.get("main_form_id"):
        await db.users.update_one(
            {"_id": ObjectId(form.main_account_id)},
            {"$set": {"main_form_id": str(result.inserted_id), "updated_at": now}}
        )

    form_dict["id"] = str(result.inserted_id)
    form_dict.pop("_id", None)
    form_dict["main_account_id"] = str(form_dict["main_account_id"])
    
    return {
        "message": "Eye health form submitted successfully",
        "data": form_dict
    }


# --------------- Get eye health form by form id ---------------
async def get_eye_health_form_by_id(form_id: str, main_account_id: str):

    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })
    
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    form["id"] = str(form["_id"])
    form["main_account_id"] = str(form["main_account_id"])
    form.pop("_id", None)

    return form


# --------------- Switch between sub accounts ---------------
async def switch_forms(main_account_id: str, form_id: str):
    
    # 1- validate the form exists and belongs to the user
    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })

    if not form:
        raise HTTPException(
            status_code=403,
            detail="Form not found or not owned by this user"
        )
        
    # 2- set all forms of this user to inactive
    await db.eye_health_forms.update_many(
        {"main_account_id": ObjectId(main_account_id)},
        {"$set": {"is_active": False, "updated_at": datetime.utcnow()}}
    )
    
    # 3- set the selected form to active
    await db.eye_health_forms.update_one(
        {"_id": ObjectId(form_id)},
        {"$set": {"is_active": True, "updated_at": datetime.utcnow()}}
    )
    
    # 4- return the updated form data
    updated_form = await db.eye_health_forms.find_one({
    "_id": ObjectId(form_id)
    })

    updated_form["id"] = str(updated_form["_id"])
    updated_form.pop("_id", None)
    updated_form["main_account_id"] = str(updated_form["main_account_id"])

    return {
        "message": "Switched to selected profile successfully",
        "active_form_id": form_id,
        "data": updated_form
    }

    
    
# --------------- Get active eye health form for a user ---------------
async def get_active_eye_health_form(main_account_id: str):
    form = await db.eye_health_forms.find_one({
        "main_account_id": ObjectId(main_account_id),
        "is_active": True
    })

    if not form:
        raise HTTPException(status_code=404, detail="No active form found")

    form["id"] = str(form["_id"])
    form["main_account_id"] = str(form["main_account_id"])
    form.pop("_id", None)
    return {"success": True, "message": "Active form fetched successfully", "data": form}



# --------------- Get all eye health forms for a user ---------------
async def get_all_eye_health_forms(main_account_id: str):
    forms_cursor = db.eye_health_forms.find({
        "main_account_id": ObjectId(main_account_id)
    }).sort("created_at", -1)  # newest first
    
    # 1) get user first (to know main_form_id)
    user = await db.users.find_one({
        "_id": ObjectId(main_account_id)
    })
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    main_form_id = user.get("main_form_id")

    forms = []
    async for f in forms_cursor:
        f["id"] = str(f["_id"])
        f["main_account_id"] = str(f["main_account_id"])
        f.pop("_id", None)
        forms.append(f)
        
    # main form first
    if main_form_id:
        forms.sort(key=lambda x: (x["id"] != main_form_id, ))

    return {
        "success": True, 
        "message": "Forms fetched successfully", 
        "main_form_id": main_form_id,
        "data": forms}



# --------------- Get main form for a user ---------------
async def get_main_eye_health_form(main_account_id: str):
    user = await db.users.find_one({"_id": ObjectId(main_account_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    main_form_id = user.get("main_form_id")
    if not main_form_id:
        raise HTTPException(status_code=404, detail="Main form not set for this user")

    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(main_form_id),
        "main_account_id": ObjectId(main_account_id)
    })
    if not form:
        raise HTTPException(status_code=404, detail="Main form not found")

    form["id"] = str(form["_id"])
    form["main_account_id"] = str(form["main_account_id"])
    form.pop("_id", None)

    return {"success": True, "message": "Main form fetched successfully", "data": form}


# --------------- Delete eye health form (sub account) ---------------
async def delete_eye_health_form(main_account_id: str, form_id: str):

    # 1) validate user exists
    user = await db.users.find_one({"_id": ObjectId(main_account_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 2) prevent deleting main form
    if user.get("main_form_id") == form_id:
        raise HTTPException(status_code=400, detail="Cannot delete main profile")

    # 3) validate form belongs to user
    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    was_active = form.get("is_active") == True

    # 4) delete it
    await db.eye_health_forms.delete_one({"_id": ObjectId(form_id)})

    # 5) if deleted form was active -> activate main form
    if was_active:
        main_form_id = user.get("main_form_id")
        if main_form_id:
            now = datetime.utcnow()

            # Make all forms inactive first
            await db.eye_health_forms.update_many(
                {"main_account_id": ObjectId(main_account_id)},
                {"$set": {"is_active": False, "updated_at": now}}
            )

            # Activate main form
            await db.eye_health_forms.update_one(
                {"_id": ObjectId(main_form_id), "main_account_id": ObjectId(main_account_id)},
                {"$set": {"is_active": True, "updated_at": now}}
            )
            
    # 6) delete all devices linked to this form (if any)
    await db.devices.delete_many({
        "user_id": main_account_id,
        "form_id": form_id
    })

    return {"success": True, "message": "Sub-account deleted successfully"}



# --------------- Toggle smart light setting ---------------
async def toggle_smart_light(form_id: str, enabled: bool):

    await db.eye_health_forms.update_one(
        {"_id": ObjectId(form_id)},
        {"$set": {
            "smart_light_enabled": enabled,
            "updated_at": datetime.utcnow()
        }}
    )

    return {
        "message": f"Smart light {'enabled' if enabled else 'disabled'}"
    }


     
# --------------- Get smart light setting (by form_id) ---------------
async def get_smart_light_state(form_id: str, main_account_id: str | None = None):

    query = {"_id": ObjectId(form_id)}
    # insure the form belongs to the user
    if main_account_id:
        query["main_account_id"] = ObjectId(main_account_id)

    form = await db.eye_health_forms.find_one(query)

    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    enabled = bool(form.get("smart_light_enabled", False))

    return {"success": True, "data": {"form_id": form_id, "enabled": enabled}}



# --------------- Get selected home charts ---------------
async def get_home_selected_charts(form_id: str, main_account_id: str):
    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })

    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    charts = form.get("home_selected_charts", [])

    return {
        "success": True,
        "message": "Home selected charts fetched successfully",
        "data": {
            "form_id": form_id,
            "home_selected_charts": charts
        }
    }



# --------------- Update selected home charts ---------------
async def update_home_selected_charts(form_id: str, main_account_id: str, charts: list[str]):
    allowed_chart_types = {
        "blinkByTime",
        "alerts",
        "blueLightScatter"
    }

    # validate values
    invalid_values = [c for c in charts if c not in allowed_chart_types]
    if invalid_values:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid chart types: {invalid_values}"
        )

    # validate form belongs to this user
    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })

    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    await db.eye_health_forms.update_one(
        {
            "_id": ObjectId(form_id),
            "main_account_id": ObjectId(main_account_id)
        },
        {
            "$set": {
                "home_selected_charts": charts,
                "updated_at": datetime.utcnow()
            }
        }
    )

    return {
        "success": True,
        "message": "Home selected charts updated successfully",
        "data": {
            "form_id": form_id,
            "home_selected_charts": charts
        }
    }

    # --------------- Update eye health form ---------------
async def update_eye_health_form(form_id: str, main_account_id: str, payload: dict):

    form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })

    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    allowed_fields = {
        "full_name",
        "date_of_birth",
        "gender",
        "previous_eye_conditions",
        "chronic_diseases",
        "uses_glasses",
        "uses_contact_lenses",
        "eye_surgery_history",
        "screen_time_hours",
        "lighting_conditions",
        "sleep_hours",
        "diet",
        "current_eye_symptoms",
        "smart_light_enabled",
    }

    update_data = {}

    for key, value in payload.items():
        if key in allowed_fields:
            update_data[key] = value

    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    update_data["updated_at"] = datetime.utcnow()

    await db.eye_health_forms.update_one(
        {
            "_id": ObjectId(form_id),
            "main_account_id": ObjectId(main_account_id)
        },
        {"$set": update_data}
    )

    updated_form = await db.eye_health_forms.find_one({
        "_id": ObjectId(form_id),
        "main_account_id": ObjectId(main_account_id)
    })

    updated_form["id"] = str(updated_form["_id"])
    updated_form["main_account_id"] = str(updated_form["main_account_id"])
    updated_form.pop("_id", None)

    return {
        "success": True,
        "message": "Eye health form updated successfully",
        "data": updated_form
    }    