import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from src.utils.database import Base


class EducationLevel(str, enum.Enum):
    preparatory = "preparatory"
    preparatory_1 = "preparatory_1"
    preparatory_2 = "preparatory_2"
    preparatory_3 = "preparatory_3"
    secondary = "secondary"
    secondary_1 = "secondary_1"
    secondary_2 = "secondary_2"
    secondary_3 = "secondary_3"


class Group(Base):
    __tablename__ = "groups"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    subject = Column(String(100), nullable=False)
    level = Column(String(50), nullable=False)
    day_of_week = Column(String(20), nullable=False)
    time_slot = Column(String(50), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    teacher = relationship("User", backref="groups")

    def __repr__(self) -> str:
        return f"<Group {self.name} - {self.subject}>"
