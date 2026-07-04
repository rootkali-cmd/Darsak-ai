import logging

logger = logging.getLogger("darsak")


async def send_push_to_user(user_id: str, title: str, body: str, data: dict = None) -> bool:
    logger.info("Push notification skipped (not configured): %s", title)
    return False
