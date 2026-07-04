import logging
from src.core.config import get_settings

logger = logging.getLogger("darsak")


class R2Service:
    def __init__(self):
        settings = get_settings()
        self.enabled = bool(settings.R2_ACCOUNT_ID and settings.R2_ACCESS_KEY_ID and settings.R2_SECRET_ACCESS_KEY)
        if not self.enabled:
            logger.info("R2 storage not configured — media uploads disabled")

    async def upload(self, teacher_id: str, folder: str, filename: str, data: bytes, mime_type: str = "application/octet-stream") -> str:
        if not self.enabled:
            return ""
        logger.warning("R2 upload called but R2 not configured")
        return ""

    async def delete(self, key: str):
        if not self.enabled:
            return
        logger.warning("R2 delete called but R2 not configured")

    async def generate_signed_url(self, key: str, expires_minutes: int = 60) -> str:
        if not self.enabled:
            return ""
        logger.warning("R2 signed URL called but R2 not configured")
        return ""


r2_service = R2Service()
