from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Request
from src.utils.dependencies import get_current_teacher, get_current_user
from src.schemas.sync import SyncPushRequest, SyncPushResponse, SyncPullResponse, SyncAckRequest, SyncAckResponse
from src.services import sync_buffer, audit_service
from src.core.security.supabase_client import get_supabase

router = APIRouter(prefix="/sync", tags=["Sync"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/push", response_model=SyncPushResponse, status_code=status.HTTP_201_CREATED)
async def push_sync(
    request: Request,
    sync_request: SyncPushRequest,
    current_user: dict = Depends(get_current_user),
):
    client = await get_supabase()
    result = await client.table("encrypted_payloads").insert({
        "teacher_id": current_user["id"],
        "payload_type": sync_request.payload_type.value if hasattr(sync_request.payload_type, 'value') else sync_request.payload_type,
        "ciphertext": sync_request.ciphertext,
        "iv": sync_request.iv,
        "auth_tag": sync_request.auth_tag,
        "sync_status": "pending",
    }).execute()

    payload_id = result.data[0]["id"]

    await sync_buffer.push_pending(
        current_user["id"],
        {
            "payload_id": payload_id,
            "type": sync_request.payload_type.value if hasattr(sync_request.payload_type, 'value') else sync_request.payload_type,
            "ciphertext": sync_request.ciphertext,
            "iv": sync_request.iv,
            "auth_tag": sync_request.auth_tag,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    )

    await audit_service.log(
        actor_type=current_user.get("role", "student"),
        action="push_sync",
        actor_id=current_user["id"],
        resource_type="sync",
        resource_id=payload_id,
        ip_address=get_client_ip(request),
        metadata={"payload_type": sync_request.payload_type.value if hasattr(sync_request.payload_type, 'value') else sync_request.payload_type},
    )

    return SyncPushResponse(
        queue_id=payload_id,
        timestamp=result.data[0]["created_at"],
    )


@router.get("/pull", response_model=SyncPullResponse)
async def pull_sync(
    since: str | None = None,
    limit: int = 50,
    current_user: dict = Depends(get_current_teacher),
):
    client = await get_supabase()
    query = client.table("encrypted_payloads").select("*").eq("teacher_id", current_user["id"]).eq("sync_status", "pending").order("created_at", desc=False).limit(limit)

    if since:
        query = query.gt("created_at", since)

    result = await query.execute()
    payloads = result.data

    items = []
    for p in payloads:
        items.append({
            "id": p["id"],
            "type": p["payload_type"],
            "ciphertext": p["ciphertext"],
            "iv": p["iv"],
            "auth_tag": p["auth_tag"],
            "timestamp": p["created_at"],
        })

    redis_items = await sync_buffer.pull_pending(current_user["id"], limit)
    for item in redis_items:
        items.append(item.get("data", item))

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="pull_sync",
        actor_id=current_user["id"],
        resource_type="sync",
        metadata={"count": len(items)},
    )

    return SyncPullResponse(items=items, total=len(items))


@router.post("/ack", response_model=SyncAckResponse)
async def ack_sync(
    request: Request,
    ack_request: SyncAckRequest,
    current_user: dict = Depends(get_current_teacher),
):
    if not ack_request.acked_ids:
        return SyncAckResponse(acknowledged=0)

    client = await get_supabase()
    for payload_id in ack_request.acked_ids:
        await client.table("encrypted_payloads").update({
            "sync_status": "synced",
            "synced_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", payload_id).eq("teacher_id", current_user["id"]).execute()

    await sync_buffer.remove_items(current_user["id"], len(ack_request.acked_ids))

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="sync_ack",
        actor_id=current_user["id"],
        resource_type="sync",
        ip_address=get_client_ip(request),
        metadata={"acknowledged": len(ack_request.acked_ids)},
    )

    return SyncAckResponse(acknowledged=len(ack_request.acked_ids))
