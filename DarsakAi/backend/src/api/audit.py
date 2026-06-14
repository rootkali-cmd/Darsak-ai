from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel

from src.utils.dependencies import get_current_teacher, get_current_admin
from src.services import audit_service

router = APIRouter(prefix="/audit", tags=["Audit"])


class AuditLogEntry(BaseModel):
    actor_type: str
    actor_id: str
    action: str
    resource_type: Optional[str] = None
    resource_id: Optional[str] = None
    before_state: Optional[dict] = None
    after_state: Optional[dict] = None
    device_id: Optional[str] = None
    ip_address: Optional[str] = None
    metadata: Optional[dict] = None


class AuditLogResponse(BaseModel):
    id: str
    actor_type: str
    actor_id: str
    action: str
    resource_type: Optional[str] = None
    resource_id: Optional[str] = None
    before_state: Optional[dict] = None
    after_state: Optional[dict] = None
    device_id: Optional[str] = None
    ip_address: Optional[str] = None
    metadata: Optional[dict] = None
    created_at: str


def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/log", status_code=status.HTTP_201_CREATED)
async def create_audit_log(
    request: Request,
    entry: AuditLogEntry,
    current_user: dict = Depends(get_current_teacher),
):
    log_entry = await audit_service.log(
        actor_type=entry.actor_type,
        actor_id=entry.actor_id,
        action=entry.action,
        resource_type=entry.resource_type,
        resource_id=entry.resource_id,
        before_state=entry.before_state,
        after_state=entry.after_state,
        device_id=entry.device_id,
        ip_address=entry.ip_address or get_client_ip(request),
        metadata=entry.metadata,
    )
    return {"id": str(log_entry["id"]), "created_at": log_entry["created_at"].isoformat() if hasattr(log_entry["created_at"], "isoformat") else log_entry["created_at"]}


@router.get("/logs", response_model=list[AuditLogResponse])
async def get_audit_logs(
    request: Request,
    actor_id: Optional[str] = Query(None, description="Filter by actor ID"),
    resource_type: Optional[str] = Query(None, description="Filter by resource type"),
    action: Optional[str] = Query(None, description="Filter by action"),
    from_date: Optional[str] = Query(None, description="Start date ISO format"),
    to_date: Optional[str] = Query(None, description="End date ISO format"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_teacher),
):
    filters = {}
    if actor_id:
        filters["actor_id"] = actor_id
    if resource_type:
        filters["resource_type"] = resource_type
    if action:
        filters["action"] = action
    if from_date:
        filters["from_date"] = from_date
    if to_date:
        filters["to_date"] = to_date

    logs = await audit_service.search(filters=filters, limit=limit, offset=offset)
    return [
        AuditLogResponse(
            id=str(log["id"]),
            actor_type=log["actor_type"],
            actor_id=str(log["actor_id"]) if log.get("actor_id") else "",
            action=log["action"],
            resource_type=log.get("resource_type"),
            resource_id=str(log["resource_id"]) if log.get("resource_id") else None,
            before_state=log.get("before_state"),
            after_state=log.get("after_state"),
            device_id=log.get("device_id"),
            ip_address=log.get("ip_address"),
            metadata=log.get("extra_metadata") or log.get("metadata"),
            created_at=log["created_at"].isoformat() if hasattr(log["created_at"], "isoformat") else str(log["created_at"]),
        )
        for log in logs
    ]


@router.get("/export", status_code=status.HTTP_200_OK)
async def export_audit_logs(
    request: Request,
    from_date: str = Query(..., description="Start date ISO format"),
    to_date: str = Query(..., description="End date ISO format"),
    current_user: dict = Depends(get_current_admin),
):
    filters = {"from_date": from_date, "to_date": to_date}
    logs = await audit_service.search(filters=filters, limit=10000, offset=0)
    import json
    lines = "\n".join(json.dumps(log, default=str) for log in logs)
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse(
        content=lines,
        media_type="application/x-ndjson",
        headers={
            "Content-Disposition": f'attachment; filename="audit_export_{datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")}.jsonl"',
        },
    )
