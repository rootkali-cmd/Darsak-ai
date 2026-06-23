from fastapi import APIRouter, Depends, HTTPException
from src.utils.dependencies import get_current_teacher
from src.schemas.assistant import (
    AssistantCreate,
    AssistantUpdate,
    AssistantResponse,
    AssistantsPasswordRequest,
    AssistantsPasswordVerifyRequest,
)
from src.services import assistant_service, user_service
from src.core.security.auth import hash_password, verify_password

router = APIRouter(prefix="/assistants", tags=["Assistants"])


@router.post("", response_model=AssistantResponse)
async def create_assistant(
    body: AssistantCreate,
    current_user: dict = Depends(get_current_teacher),
):
    data = body.model_dump(exclude_unset=True)
    data["payment_status"] = data.get("payment_status", "unpaid")
    return await assistant_service.create(
        teacher_id=current_user["id"],
        **data,
    )


@router.get("", response_model=list[AssistantResponse])
async def list_assistants(
    current_user: dict = Depends(get_current_teacher),
):
    return await assistant_service.list_by_teacher(current_user["id"])


@router.get("/{assistant_id}", response_model=AssistantResponse)
async def get_assistant(
    assistant_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    assistant = await assistant_service.get_by_id(assistant_id)
    if not assistant or assistant["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Assistant not found")
    return assistant


@router.patch("/{assistant_id}", response_model=AssistantResponse)
async def update_assistant(
    assistant_id: str,
    body: AssistantUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    assistant = await assistant_service.get_by_id(assistant_id)
    if not assistant or assistant["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Assistant not found")
    data = body.model_dump(exclude_unset=True)
    return await assistant_service.update(assistant_id, data)


@router.delete("/{assistant_id}")
async def delete_assistant(
    assistant_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    assistant = await assistant_service.get_by_id(assistant_id)
    if not assistant or assistant["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=404, detail="Assistant not found")
    await assistant_service.delete(assistant_id)
    return {"ok": True}


@router.post("/set-password")
async def set_assistants_password(
    body: AssistantsPasswordRequest,
    current_user: dict = Depends(get_current_teacher),
):
    pw_hash = hash_password(body.password)
    await user_service.update(current_user["id"], {"assistants_password_hash": pw_hash})
    return {"ok": True, "message": "Password set successfully"}


@router.post("/verify-password")
async def verify_assistants_password(
    body: AssistantsPasswordVerifyRequest,
    current_user: dict = Depends(get_current_teacher),
):
    user = await user_service.get_by_id(current_user["id"])
    stored_hash = user.get("assistants_password_hash") if user else None
    if not stored_hash:
        raise HTTPException(status_code=400, detail="No password set. Please set a password first.")
    if not verify_password(body.password, stored_hash):
        raise HTTPException(status_code=401, detail="Incorrect password")
    return {"ok": True, "message": "Password verified"}
