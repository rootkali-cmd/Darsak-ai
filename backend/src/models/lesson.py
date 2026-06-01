from datetime import datetime, timezone
from uuid import uuid4
from sqlalchemy import Column, String, Text, Integer, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from src.utils.database import Base


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    teacher_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    group_id = Column(String(36), ForeignKey("groups.id"), nullable=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    subject = Column(String(100), nullable=True)
    week_number = Column(Integer, nullable=True)
    video_url = Column(Text, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    tg_message_id = Column(String(100), nullable=True, index=True)
    tg_file_id = Column(Text, nullable=True)
    is_published = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    teacher = relationship("User")
    group = relationship("Group")
