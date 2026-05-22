import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from src.utils.database import Base


class PayloadType(str, enum.Enum):
    grade = "grade"
    attendance = "attendance"
    invoice = "invoice"
    ai_report = "ai_report"
    student = "student"
    group = "group"


class SyncStatus(str, enum.Enum):
    pending = "pending"
    synced = "synced"
    failed = "failed"


class EncryptedPayload(Base):
    __tablename__ = "encrypted_payloads"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    payload_type = Column(Enum(PayloadType), nullable=False)
    ciphertext = Column(Text, nullable=False)
    iv = Column(Text, nullable=False)
    auth_tag = Column(Text, nullable=False)
    sync_status = Column(Enum(SyncStatus), default=SyncStatus.pending, index=True)
    synced_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    teacher = relationship("User")

    def __repr__(self) -> str:
        return f"<EncryptedPayload {self.payload_type} - {self.sync_status}>"
