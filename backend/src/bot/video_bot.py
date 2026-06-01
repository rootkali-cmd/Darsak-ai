import os
import logging
import asyncio
import aiofiles
from io import BytesIO
from typing import Optional

import httpx

from src.core.config import get_settings

logger = logging.getLogger("darsak.video_bot")


class VideoBotService:
    """Dedicated Telegram bot for handling video files—completely separate from the payment bot."""

    def __init__(self, bot_token: str | None = None):
        settings = get_settings()
        self.bot_token = bot_token or settings.VIDEO_TELEGRAM_BOT_TOKEN
        self.api_base = f"https://api.telegram.org/bot{self.bot_token}" if self.bot_token else ""
        self.http = httpx.AsyncClient(timeout=httpx.Timeout(connect=10, read=300, write=300, pool=30))

    @property
    def is_configured(self) -> bool:
        return bool(self.bot_token and len(self.bot_token) > 5)

    async def _call(self, method: str, **kwargs) -> dict:
        if not self.is_configured:
            return {"ok": False, "error": "Video bot token not configured"}
        try:
            resp = await self.http.post(f"{self.api_base}/{method}", json=kwargs)
            resp.raise_for_status()
            return resp.json()
        except Exception as exc:
            logger.error("Telegram API error [%s]: %s", method, exc)
            return {"ok": False, "error": str(exc)}

    async def create_channel(self, teacher_name: str) -> dict:
        """Create a private Telegram channel for a teacher. Returns {ok, channel_id, invite_link}."""
        clean_name = teacher_name.replace(" ", "_")[:32] or "Teacher"
        result = await self._call(
            "createChat",
            title=f"DarsakAI - {teacher_name}",
            username=f"darsak_{clean_name.lower()}_{os.urandom(2).hex()}",
            type="channel",
        )
        if result.get("ok"):
            chat = result.get("result", {})
            return {
                "ok": True,
                "channel_id": str(chat.get("id", "")),
                "title": chat.get("title", ""),
            }
        return result

    async def send_video(
        self,
        chat_id: str,
        file_path: str | None = None,
        file_data: bytes | None = None,
        file_name: str = "video.mp4",
        caption: str = "",
        supports_streaming: bool = True,
    ) -> dict:
        """Upload a video file to a specific chat/channel. Returns {ok, message_id, file_id}."""
        if not self.is_configured:
            return {"ok": False, "error": "Video bot token not configured"}

        try:
            files = {}
            if file_path:
                async with aiofiles.open(file_path, "rb") as f:
                    file_data = await f.read()
                    file_name = os.path.basename(file_path)

            if file_data is None:
                return {"ok": False, "error": "No file data provided"}

            files["video"] = (file_name, BytesIO(file_data), "video/mp4")

            data = {
                "chat_id": chat_id,
                "caption": caption,
                "supports_streaming": supports_streaming,
                "parse_mode": "HTML",
            }

            resp = await self.http.post(
                f"{self.api_base}/sendVideo",
                data={k: str(v) for k, v in data.items()},
                files=files,
                timeout=httpx.Timeout(connect=10, read=600, write=600, pool=30),
            )
            resp.raise_for_status()
            result = resp.json()
            if result.get("ok"):
                msg = result.get("result", {})
                video = msg.get("video", {})
                return {
                    "ok": True,
                    "message_id": str(msg.get("message_id", "")),
                    "file_id": video.get("file_id", ""),
                    "file_unique_id": video.get("file_unique_id", ""),
                    "duration": video.get("duration", 0),
                }
            return result
        except Exception as exc:
            logger.error("sendVideo error: %s", exc)
            return {"ok": False, "error": str(exc)}

    async def get_file_url(self, file_id: str) -> Optional[str]:
        """Get the direct file download URL for a Telegram file_id using the bot token."""
        try:
            resp = await self._call("getFile", file_id=file_id)
            if resp.get("ok"):
                file_path = resp.get("result", {}).get("file_path", "")
                if file_path:
                    return f"https://api.telegram.org/file/bot{self.bot_token}/{file_path}"
        except Exception:
            pass
        return None

    async def forward_video_to_chat(self, from_chat_id: str, to_chat_id: str, message_id: str) -> dict:
        return await self._call(
            "forwardMessage",
            chat_id=to_chat_id,
            from_chat_id=from_chat_id,
            message_id=message_id,
        )

    async def get_channel_info(self, chat_id: str) -> dict:
        resp = await self._call("getChat", chat_id=chat_id)
        return resp

    async def close(self):
        await self.http.aclose()


video_bot_service = VideoBotService()
