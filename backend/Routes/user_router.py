from fastapi import APIRouter, Body
from Models.user_model import UserModel
from Controllers.user_controller import (
    create_main_account,
    login,
    delete_main_account,
    get_user_by_firebase_uid,
    update_fcm_token,
    update_user_account
)

router = APIRouter()

# --------- Create new main-account ---------
@router.post("/register-main")
async def register_user(user: UserModel):
    return await create_main_account(user)


# --------- login ---------
@router.post("/login")
async def login_user(id_token: str):
    return await login(id_token)


# --------- delete main-account ---------
@router.delete("/delete-main")
async def delete_main_account_route(main_uid: str):
    return await delete_main_account(main_uid)
    
# --------- update info ---------
@router.put("/{firebase_uid}")
async def update_user(firebase_uid: str, payload: dict = Body(...)):
    return await update_user_account(firebase_uid, payload)

# --------- جلب بيانات المستخدم بواسطة Firebase UID ---------
@router.get("/{firebase_uid}")
async def get_user(firebase_uid: str):
    return await get_user_by_firebase_uid(firebase_uid)


# --------- تحديث FCM Token ---------
@router.post("/update-fcm-token")
async def update_fcm_token_route(user_id: str, fcm_token: str):
    return await update_fcm_token(user_id, fcm_token)