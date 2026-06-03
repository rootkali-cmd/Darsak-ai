from datetime import datetime
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_teacher
from src.schemas.invoice import InvoiceCreate, InvoiceUpdate, InvoiceResponse
from src.services import invoice_service, student_service, audit_service
from src.core.subscription_guard import enforce_invoice_limit

router = APIRouter(prefix="/invoices", tags=["Invoices"])


def _to_response(data: dict) -> dict:
    result = {}
    for key, value in data.items():
        if hasattr(value, 'isoformat'):
            result[key] = value.isoformat()
        elif isinstance(value, UUID) or hasattr(value, 'hex'):
            result[key] = str(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_invoice(
    invoice_data: InvoiceCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        await enforce_invoice_limit(current_user["id"])

        student = await student_service.get_by_id(str(invoice_data.student_id))
        if not student or student["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

        invoice = await invoice_service.create(
            teacher_id=current_user["id"],
            student_id=str(invoice_data.student_id),
            amount=invoice_data.amount,
            description=invoice_data.description,
            paid=invoice_data.paid,
            payment_date=invoice_data.payment_date.isoformat() if invoice_data.payment_date else None,
            signature=invoice_data.signature,
        )

        await audit_service.log(
            actor_type=current_user.get("role", "teacher"),
            action="invoice_created",
            actor_id=current_user["id"],
            resource_type="invoice",
            resource_id=invoice["id"],
            ip_address=get_client_ip(request),
        )

        return _to_response(invoice)
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to create invoice: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to create invoice: {str(exc)}")


@router.get("/")
async def list_invoices(
    student_id: str | None = None,
    paid: bool | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    filters = {"teacher_id": current_user["id"]}
    if student_id:
        filters["student_id"] = student_id

    invoices = await invoice_service.list(filters, limit=limit, offset=skip)
    if paid is not None:
        invoices = [i for i in invoices if i.get("paid") == paid]

    return [_to_response(i) for i in invoices]


@router.patch("/{invoice_id}")
async def update_invoice(
    invoice_id: str,
    update_data: InvoiceUpdate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    invoices = await invoice_service.list({"teacher_id": current_user["id"]}, limit=200)
    invoice = next((i for i in invoices if i["id"] == invoice_id), None)
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")

    data = update_data.model_dump(exclude_unset=True)
    if "payment_date" in data and data["payment_date"]:
        data["payment_date"] = data["payment_date"].isoformat()

    updated = await invoice_service.update(invoice_id, data)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="invoice_updated",
        actor_id=current_user["id"],
        resource_type="invoice",
        resource_id=invoice_id,
        ip_address=get_client_ip(request),
    )

    return _to_response(updated)


@router.put("/{invoice_id}")
async def update_invoice_put(
    invoice_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        existing = await invoice_service.get_by_id(invoice_id)
        if not existing or existing.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

        body = await request.json()
        update_dict = {k: v for k, v in body.items() if v is not None and k not in ("id", "teacher_id")}
        updated = await invoice_service.update(invoice_id, update_dict)

        await audit_service.log(
            actor_type=current_user.get("role", "teacher"),
            action="invoice_updated",
            actor_id=current_user["id"],
            resource_type="invoice",
            resource_id=invoice_id,
            ip_address=get_client_ip(request),
        )

        return {
            "ok": True,
            "data": {
                k: str(v) if hasattr(v, "hex") else (v.isoformat() if hasattr(v, "isoformat") else v)
                for k, v in updated.items()
            }
        }
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to update invoice %s: %s", invoice_id, exc)
        raise HTTPException(status_code=500, detail="Update failed")


@router.delete("/{invoice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_invoice(
    invoice_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    invoices = await invoice_service.list({"teacher_id": current_user["id"]}, limit=200)
    invoice = next((i for i in invoices if i["id"] == invoice_id), None)
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")

    await invoice_service.delete(invoice_id)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="invoice_deleted",
        actor_id=current_user["id"],
        resource_type="invoice",
        resource_id=invoice_id,
        ip_address=get_client_ip(request),
    )


@router.get("/stats")
async def invoice_stats(current_user: dict = Depends(get_current_teacher)):
    stats = await invoice_service.get_stats(current_user["id"])
    return stats
