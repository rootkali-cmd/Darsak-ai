import uuid
from datetime import datetime, date, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Enum, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum

from src.utils.database import Base


class AttendanceStatus(str, enum.Enum):
    present = "present"
    absent = "absent"
    cancelled = "cancelled"


class Attendance(Base):
    __tablename__ = "attendances"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False, index=True)
    group_id = Column(UUID(as_uuid=True), ForeignKey("groups.id"), nullable=True, index=True)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    status = Column(Enum(AttendanceStatus), nullable=False, default=AttendanceStatus.absent)
    date = Column(Date, nullable=False, default=lambda: datetime.now(timezone.utc).date(), index=True)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    student = relationship("Student", back_populates="attendances")
    group = relationship("Group")
    teacher = relationship("User")

    def __repr__(self) -> str:
        return f"<Attendance {self.student_id} - {self.status} - {self.date}>"
