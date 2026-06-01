from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from src.utils.database import Base


class VideoAnalytics(Base):
    __tablename__ = "video_analytics"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    student_id = Column(String(36), ForeignKey("students.id"), nullable=False, index=True)
    video_id = Column(String(36), ForeignKey("lessons.id"), nullable=False, index=True)
    teacher_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    last_position = Column(Integer, default=0)
    max_watched_duration = Column(Integer, default=0)
    current_speed = Column(Float, default=1.0)
    is_completed = Column(Boolean, default=False)
    is_flagged_cheated = Column(Boolean, default=False)
    is_delayed = Column(Boolean, default=False)
    delay_reason = Column(String(100), nullable=True)
    last_event_type = Column(String(50), nullable=True)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    student = relationship("Student")
    video = relationship("Lesson")
    teacher = relationship("User")
