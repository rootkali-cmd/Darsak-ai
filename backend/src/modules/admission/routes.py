import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from src.utils.dependencies import get_current_teacher
from src.core.security.supabase_repo import get_supabase

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/admission")


@router.get("/pending")
async def get_pending_admissions(current_user: dict = Depends(get_current_teacher)):
    try:
        client = await get_supabase()
        result = (
            await client.table("student_admission_requests")
            .select("*")
            .eq("teacher_id", current_user["id"])
            .eq("status", "pending")
            .order("created_at", desc=True)
            .execute()
        )
        return {"items": result.data or []}
    except Exception as e:
        logger.error("get_pending_admissions failed: %s", e)
        return {"items": []}


@router.post("/{request_id}/approve")
async def approve_admission(request_id: str, current_user: dict = Depends(get_current_teacher)):
    try:
        client = await get_supabase()
        result = await (
            client.table("student_admission_requests")
            .select("*")
            .eq("id", request_id)
            .eq("teacher_id", current_user["id"])
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="الطلب غير موجود")
        req = result.data[0]
        if req.get("status") != "pending":
            raise HTTPException(status_code=400, detail="تم معالجة هذا الطلب مسبقاً")
        import uuid
        code = f"STU-{uuid.uuid4().hex[:8].upper()}"
        student_data = {
            "teacher_id": current_user["id"],
            "full_name": req["full_name"],
            "code": code,
            "is_active": True,
            "registration_type": req.get("registration_type", "online"),
        }
        if req.get("phone"):
            student_data["phone"] = req["phone"]
        if req.get("grade_level"):
            student_data["grade_level"] = req["grade_level"]
        student_result = await client.table("students").insert(student_data).execute()
        student = student_result.data[0] if student_result.data else None
        await (
            client.table("student_admission_requests")
            .update({
                "status": "approved",
                "student_id": student["id"] if student else None,
                "approved_by": current_user["id"],
                "approved_at": "now()",
            })
            .eq("id", request_id)
            .execute()
        )
        return {"ok": True, "student_code": code, "student_id": student["id"] if student else None}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("approve_admission failed: %s", e)
        raise HTTPException(status_code=500, detail="internal error")


class RejectReason(BaseModel):
    reason: Optional[str] = None


@router.post("/{request_id}/reject")
async def reject_admission(request_id: str, body: RejectReason, current_user: dict = Depends(get_current_teacher)):
    try:
        client = await get_supabase()
        result = await (
            client.table("student_admission_requests")
            .select("*")
            .eq("id", request_id)
            .eq("teacher_id", current_user["id"])
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="الطلب غير موجود")
        req = result.data[0]
        if req.get("status") != "pending":
            raise HTTPException(status_code=400, detail="تم معالجة هذا الطلب مسبقاً")
        await (
            client.table("student_admission_requests")
            .update({
                "status": "rejected",
                "rejection_reason": body.reason or "",
                "approved_by": current_user["id"],
            })
            .eq("id", request_id)
            .execute()
        )
        return {"ok": True}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("reject_admission failed: %s", e)
        raise HTTPException(status_code=500, detail="internal error")


@router.post("/register-online")
async def register_online():
    return {"detail": "يجب التواصل مع المدرس مباشرة"}
