import logging
from typing import Optional

logger = logging.getLogger("darsak")


async def send_push_notification(token: str, title: str, body: str, data: Optional[dict] = None) -> bool:
    logger.info("FCM push skipped (service not configured): %s", title)
    return False


async def send_push_to_all(tokens: list[str], title: str, body: str, data: Optional[dict] = None) -> int:
    logger.info("FCM push-all skipped (service not configured): %s", title)
    return 0


async def send_push_to_students_of_teacher(teacher_id: str, title: str, body: str, data: Optional[dict] = None) -> int:
    logger.info("FCM push-to-students skipped (service not configured): %s", title)
    return 0
