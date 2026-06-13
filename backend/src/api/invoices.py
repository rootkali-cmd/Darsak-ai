import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Request

logger = logging.getLogger("darsak")

from src.utils.dependencies import get_current_teacher, get_current_student, get_current_user
from src.schemas.invoice import (
    InvoiceCreateRequest,
    InvoiceUploadProof,
    InvoiceApproveReject,
    InvoiceResponse,
    InvoiceWithLesson,
)
from src.core.security.supabase_repo import SupabaseRepository

router = APIRouter(prefix="/invoices", tags=["Invoices"])

invoice_repo = SupabaseRepository("invoices")
lesson_repo = SupabaseRepository("lessons")
student_repo = SupabaseRepository("students")


def _serialize_invoice(inv: dict) -> dict:
    return {
        "id": str(inv.get("id", "")),
        "student_id": str(inv.get("student_id", "")),
        "lesson_id": str(inv.get("lesson_id", "")) if inv.get("lesson_id") else None,
        "teacher_id": str(inv.get("teacher_id", "")),
        "amount": float(inv.get("amount", 0)),
        "currency": inv.get("currency", "EGP"),
        "payment_method": inv.get("payment_method"),
        "screenshot_url": inv.get("screenshot_url"),
        "status": inv.get("status", "pending"),
        "teacher_note": inv.get("teacher_note"),
        "created_at": str(inv.get("created_at", "")),
        "updated_at": str(inv.get("updated_at", "")),
    }


def _serialize_lesson(lesson: dict | None) -> dict | None:
    if not lesson:
        return None
    return {
        "id": str(lesson.get("id", "")),
        "title": lesson.get("title", ""),
        "subject": lesson.get("subject"),
        "week_number": lesson.get("week_number"),
        "description": lesson.get("description"),
    }


# ─── 1. Student creates invoice ──────────────────────────────────────

@router.post("/create", response_model=InvoiceResponse, status_code=status.HTTP_201_CREATED)
async def create_invoice(
    data: InvoiceCreateRequest,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    try:
        if current_student["id"] != str(data.student_id):
            raise HTTPException(status_code=403, detail="Cannot create invoice for another student")

        lesson = None
        teacher_id = None
        if data.lesson_id:
            lesson = await lesson_repo.select_one({"id": str(data.lesson_id)})
            if not lesson:
                raise HTTPException(status_code=404, detail="Lesson not found")
            teacher_id = lesson.get("teacher_id")
        else:
            student = await student_repo.select_one({"id": str(data.student_id)})
            if not student:
                raise HTTPException(status_code=404, detail="Student not found")
            teacher_id = student.get("teacher_id")

        if not teacher_id:
            raise HTTPException(status_code=400, detail="Could not determine teacher for this invoice")

        invoice_data = {
            "student_id": str(data.student_id),
            "lesson_id": str(data.lesson_id) if data.lesson_id else None,
            "teacher_id": str(teacher_id),
            "amount": data.amount,
            "payment_method": data.payment_method,
            "status": "pending",
        }

        invoice = await invoice_repo.insert(invoice_data)

        return InvoiceResponse(**_serialize_invoice(invoice))

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create invoice: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create invoice: {str(exc)}")


# ─── 1b. Teacher creates invoice for student ──────────────────────────

@router.post("/teacher-create", response_model=InvoiceResponse, status_code=status.HTTP_201_CREATED)
async def teacher_create_invoice(
    data: InvoiceCreateRequest,
    current_teacher: dict = Depends(get_current_teacher),
):
    try:
        student = await student_repo.select_one({"id": str(data.student_id)})
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        if student.get("teacher_id") != current_teacher["id"]:
            raise HTTPException(status_code=403, detail="Student does not belong to you")

        invoice_data = {
            "student_id": str(data.student_id),
            "lesson_id": str(data.lesson_id) if data.lesson_id else None,
            "teacher_id": str(current_teacher["id"]),
            "amount": data.amount,
            "payment_method": data.payment_method,
            "status": "paid",
        }

        invoice = await invoice_repo.insert(invoice_data)
        return InvoiceResponse(**_serialize_invoice(invoice))

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Teacher failed to create invoice: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create invoice: {str(exc)}")


# ─── 2. Student views their invoices ─────────────────────────────────

@router.get("/my/{student_id}", response_model=list[InvoiceWithLesson])
async def get_my_invoices(
    student_id: str,
    status_filter: str | None = None,
    current_user: dict = Depends(get_current_user),
):
    try:
        role = current_user.get("role", "")
        if role == "student" and current_user["id"] != student_id:
            raise HTTPException(status_code=403, detail="Access denied")

        invoices = await invoice_repo.select(
            {"student_id": student_id},
            limit=100,
        )

        if status_filter and status_filter in ("pending", "paid", "rejected"):
            invoices = [i for i in invoices if i.get("status") == status_filter]

        results = []
        for inv in invoices:
            lesson = None
            if inv.get("lesson_id"):
                try:
                    lesson = await lesson_repo.select_one({"id": inv["lesson_id"]})
                except Exception:
                    pass
            item = _serialize_invoice(inv)
            item["lesson"] = _serialize_lesson(lesson)
            results.append(InvoiceWithLesson(**item))

        return results

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to fetch invoices for student %s: %s", student_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch invoices: {str(exc)}")


# ─── 3. Student uploads payment proof ────────────────────────────────

@router.post("/upload-proof", response_model=InvoiceResponse)
async def upload_payment_proof(
    data: InvoiceUploadProof,
    request: Request,
    current_student: dict = Depends(get_current_student),
):
    try:
        invoice = await invoice_repo.select_one({"id": data.invoice_id})
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")

        if invoice["student_id"] != current_student["id"]:
            raise HTTPException(status_code=403, detail="Access denied")

        if invoice.get("status") != "pending":
            raise HTTPException(status_code=400, detail="Invoice is not pending")

        now = datetime.now(timezone.utc).isoformat()
        updated = await invoice_repo.update(
            {"id": data.invoice_id},
            {"screenshot_url": data.screenshot_url, "updated_at": now},
        )

        return InvoiceResponse(**_serialize_invoice(updated))

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to upload payment proof: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to upload proof: {str(exc)}")


# ─── 4. Teacher views pending invoices ───────────────────────────────

@router.get("/pending", response_model=list[InvoiceWithLesson])
async def get_pending_invoices(
    current_user: dict = Depends(get_current_teacher),
):
    return await _get_teacher_invoices(current_user, status_filter="pending")


@router.get("/teacher", response_model=list[InvoiceWithLesson])
async def get_all_teacher_invoices(
    current_user: dict = Depends(get_current_teacher),
):
    return await _get_teacher_invoices(current_user, status_filter=None)


async def _get_teacher_invoices(current_user: dict, status_filter: str | None) -> list[InvoiceWithLesson]:
    try:
        invoices = await invoice_repo.select(
            {"teacher_id": current_user["id"]},
            limit=200,
        )

        if status_filter:
            invoices = [i for i in invoices if i.get("status") == status_filter]

        results = []
        for inv in invoices:
            lesson = None
            student_name = "طالب"
            if inv.get("lesson_id"):
                try:
                    lesson = await lesson_repo.select_one({"id": inv["lesson_id"]})
                except Exception:
                    pass
            if inv.get("student_id"):
                try:
                    stu = await student_repo.select_one({"id": inv["student_id"]})
                    if stu:
                        student_name = stu.get("full_name", "طالب")
                except Exception:
                    pass
            item = _serialize_invoice(inv)
            item["lesson"] = _serialize_lesson(lesson)
            item["student_name"] = student_name
            results.append(InvoiceWithLesson(**item))

        return results

    except Exception as exc:
        logger.error("Failed to fetch teacher invoices: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch invoices: {str(exc)}")


# ─── 5. Teacher approves invoice ─────────────────────────────────────

@router.post("/{invoice_id}/approve", response_model=InvoiceResponse)
async def approve_invoice(
    invoice_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        invoice = await invoice_repo.select_one({"id": invoice_id})
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")

        if invoice["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Access denied")

        if invoice.get("status") != "pending":
            raise HTTPException(status_code=400, detail="Invoice is not pending")

        now = datetime.now(timezone.utc).isoformat()
        updated = await invoice_repo.update({"id": invoice_id}, {"status": "paid", "updated_at": now})

        try:
            from src.services import notification_service
            await notification_service.create(
                teacher_id=invoice["student_id"],
                title="✅ تم قبول الفاتورة",
                body=f"تمت الموافقة على فاتورة بقيمة {invoice.get('amount', 0)} جنيه",
                type="payment",
            )
        except Exception:
            pass

        return InvoiceResponse(**_serialize_invoice(updated))

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to approve invoice %s: %s", invoice_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to approve invoice: {str(exc)}")


# ─── 6. Teacher rejects invoice ──────────────────────────────────────

@router.post("/{invoice_id}/reject", response_model=InvoiceResponse)
async def reject_invoice(
    invoice_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        invoice = await invoice_repo.select_one({"id": invoice_id})
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")

        if invoice["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Access denied")

        if invoice.get("status") != "pending":
            raise HTTPException(status_code=400, detail="Invoice is not pending")

        now = datetime.now(timezone.utc).isoformat()
        updated = await invoice_repo.update({"id": invoice_id}, {"status": "rejected", "updated_at": now})

        try:
            from src.services import notification_service
            await notification_service.create(
                teacher_id=invoice["student_id"],
                title="❌ تم رفض الفاتورة",
                body=f"تم رفض فاتورة بقيمة {invoice.get('amount', 0)} جنيه. تواصل مع معلمك للمزيد من التفاصيل",
                type="payment",
            )
        except Exception:
            pass

        return InvoiceResponse(**_serialize_invoice(updated))

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to reject invoice %s: %s", invoice_id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to reject invoice: {str(exc)}")
