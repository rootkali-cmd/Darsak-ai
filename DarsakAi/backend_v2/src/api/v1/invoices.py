import logging

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from src.api.deps import get_current_teacher
from src.core.exceptions import BadRequestException, NotFoundException, ForbiddenException
from src.services.invoice_service import invoice_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/invoices")


class CreateInvoiceRequest(BaseModel):
    student_id: str
    amount: float
    description: str | None = None
    due_date: str | None = None
    status: str | None = None


class UpdateInvoiceRequest(BaseModel):
    student_id: str | None = None
    amount: float | None = None
    description: str | None = None
    due_date: str | None = None
    status: str | None = None


@router.get("/")
async def list_invoices(
    status: str | None = Query(None),
    student_id: str | None = Query(None),
    limit: int = Query(200, le=2000),
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        invoices = await invoice_service.list_by_teacher(
            teacher_id=teacher_id,
            status=status,
            student_id=student_id,
            limit=limit,
        )
        return {"data": invoices}
    except Exception as e:
        logger.error(f"Error listing invoices: {e}", exc_info=True)
        raise BadRequestException("Failed to list invoices")


@router.post("/")
async def create_invoice(
    body: CreateInvoiceRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        data = {
            "student_id": body.student_id,
            "amount": body.amount,
            "teacher_id": teacher_id,
        }
        if body.description is not None:
            data["description"] = body.description
        if body.due_date is not None:
            data["due_date"] = body.due_date
        if body.status is not None:
            data["status"] = body.status
        invoice = await invoice_service.create(data)
        return invoice
    except Exception as e:
        logger.error(f"Error creating invoice: {e}", exc_info=True)
        raise BadRequestException("Failed to create invoice")


@router.put("/{invoice_id}")
async def update_invoice(
    invoice_id: str,
    body: UpdateInvoiceRequest,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await invoice_service.get_by_id(invoice_id)
        if not existing:
            raise NotFoundException("Invoice not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your invoice")

        data = {}
        if body.student_id is not None:
            data["student_id"] = body.student_id
        if body.amount is not None:
            data["amount"] = body.amount
        if body.description is not None:
            data["description"] = body.description
        if body.due_date is not None:
            data["due_date"] = body.due_date
        if body.status is not None:
            data["status"] = body.status
        if not data:
            raise BadRequestException("No fields to update")
        invoice = await invoice_service.update(invoice_id, data)
        return invoice
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except BadRequestException:
        raise
    except Exception as e:
        logger.error(f"Error updating invoice {invoice_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to update invoice")


@router.delete("/{invoice_id}")
async def delete_invoice(
    invoice_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        existing = await invoice_service.get_by_id(invoice_id)
        if not existing:
            raise NotFoundException("Invoice not found")
        if str(existing.get("teacher_id")) != str(teacher["id"]):
            raise ForbiddenException("Not your invoice")

        deleted = await invoice_service.delete(invoice_id)
        if not deleted:
            raise NotFoundException("Invoice not found")
        return {"deleted": True}
    except NotFoundException:
        raise
    except ForbiddenException:
        raise
    except Exception as e:
        logger.error(f"Error deleting invoice {invoice_id}: {e}", exc_info=True)
        raise BadRequestException("Failed to delete invoice")


@router.get("/stats")
async def invoice_stats(
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = teacher["id"]
        stats = await invoice_service.get_stats(teacher_id)
        return stats
    except Exception as e:
        logger.error(f"Error getting invoice stats: {e}", exc_info=True)
        raise BadRequestException("Failed to get invoice stats")
