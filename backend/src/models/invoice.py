import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Float, Boolean, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from src.utils.database import Base


class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    description = Column(String(500), nullable=True)
    paid = Column(Boolean, default=False)
    payment_date = Column(Date, nullable=True)
    signature = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    teacher = relationship("User")
    student = relationship("Student")

    def __repr__(self) -> str:
        return f"<Invoice {self.id} - {self.amount} - {'paid' if self.paid else 'unpaid'}>"
