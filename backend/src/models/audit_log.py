import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Enum
from sqlalchemy.dialects.postgresql import UUID, JSONB, INET
from sqlalchemy.orm import relationship
import enum

from src.utils.database import Base


class ActorType(str, enum.Enum):
    student = "student"
    teacher = "teacher"
    assistant = "assistant"
    system = "system"


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_type = Column(Enum(ActorType), nullable=False)
    actor_id = Column(UUID(as_uuid=True), nullable=True)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50), nullable=True)
    resource_id = Column(UUID(as_uuid=True), nullable=True)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)
    timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)
    extra_metadata = Column("metadata", JSONB, nullable=True)

    def __repr__(self) -> str:
        return f"<AuditLog {self.action} by {self.actor_type} at {self.timestamp}>"
