from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from src.models.encrypted_payload import PayloadType


class SyncPushRequest(BaseModel):
    payload_type: PayloadType
    ciphertext: str
    iv: str
    auth_tag: str


class SyncPushResponse(BaseModel):
    status: str = "buffered"
    queue_id: UUID
    timestamp: datetime


class SyncPullResponse(BaseModel):
    items: list[dict]
    total: int


class SyncAckRequest(BaseModel):
    acked_ids: list[UUID]


class SyncAckResponse(BaseModel):
    acknowledged: int
