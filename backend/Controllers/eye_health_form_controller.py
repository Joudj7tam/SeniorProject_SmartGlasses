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

    form_dict = form.dict()
    now = datetime.utcnow()

    form_dict["created_at"] = now
    form_dict["updated_at"] = now
    form_dict["is_active"] = False  # New forms are inactive by default
    form_dict["main_account_id"] = ObjectId(form.main_account_id) # Convert to ObjectId for MongoDB storage

    # 3- insert form
    result = await db.eye_health_forms.insert_one(form_dict)
    if not result.inserted_id:
        raise HTTPException(
            status_code=500,
            detail="Error saving eye health form"
        )

    form_dict["id"] = str(result.inserted_id)
    form_dict.pop("_id", None)

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
        {"$set": {"is_active": False}}
    )
    
    # 3- set the selected form to active
    await db.eye_health_forms.update_one(
        {"_id": ObjectId(form_id)},
        {"$set": {"is_active": True}}
    )
    
    # 4- return the updated form data
    updated_form = await db.eye_health_forms.find_one({
    "_id": ObjectId(form_id)
    })

    updated_form["id"] = str(updated_form["_id"])
    updated_form.pop("_id", None)

    return {
        "message": "Switched to selected profile successfully",
        "active_form_id": form_id,
        "data": updated_form
    }

     
     