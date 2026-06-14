import os
import logging
import httpx
from src.core.config import get_settings

logger = logging.getLogger("darsak.video_bot")
settings = get_settings()

class VideoBotService:
    def __init__(self, bot_token: str | None = None):
        self.bot_token = bot_token or os.environ.get("VIDEO_TELEGRAM_BOT_TOKEN", os.environ.get("TELEGRAM_BOT_TOKEN", ""))
        self.api_base = f"https://api.telegram.org/bot{self.bot_token}" if self.bot_token else ""
        self.http = httpx.AsyncClient(timeout=httpx.Timeout(connect=10, read=600, write=600, pool=30))

    @property
    def is_configured(self) -> bool:
        return bool(self.bot_token and len(self.bot_token) > 5)

    async def _call(self, method: str, **kwargs) -> dict:
        if not self.is_configured:
            return {"ok": False, "error": "Bot token not configured"}
        try:
            resp = await self.http.post(f"{self.api_base}/{method}", json=kwargs)
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.error("Telegram API error [%s]: %s", method, e)
            return {"ok": False, "error": str(e)}

    async def create_channel(self, teacher_name: str) -> dict:
        """Create a private channel for a teacher. Returns {ok, channel_id, title, invite_link}."""
        clean_name = teacher_name.replace(" ", "_")[:32]
        import secrets
        result = await self._call(
            "createChat",
            title=f"DarsakAI - {teacher_name}",
            username=f"darsak_{clean_name.lower()}_{secrets.token_hex(2)}",
            type="channel",
        )
        if result.get("ok"):
            chat = result.get("result", {})
            channel_id = str(chat.get("id", ""))
            # Set channel to private (only bot can access)
            await self._call("setChatPermissions", chat_id=channel_id, permissions={"can_send_messages": False})
            return {
                "ok": True,
                "channel_id": channel_id,
                "title": chat.get("title", ""),
                "invite_link": chat.get("invite_link", ""),
            }
        return result

    async def send_video(
        self,
        chat_id: str,
        file_data: bytes,
        file_name: str = "video.mp4",
        caption: str = "",
        supports_streaming: bool = True,
    ) -> dict:
        """Upload video to channel. Returns {ok, message_id, file_id, duration}."""
        if not self.is_configured:
            return {"ok": False, "error": "Bot token not configured"}
        try:
            from io import BytesIO
            files = {"video": (file_name, BytesIO(file_data), "video/mp4")}
            data = {
                "chat_id": chat_id,
                "caption": caption,
                "supports_streaming": str(supports_streaming).lower(),
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
        except Exception as e:
            logger.error("sendVideo error: %s", e)
            return {"ok": False, "error": str(e)}

    async def get_file_url(self, file_id: str) -> str | None:
        """Get direct download URL for a file. Returns None on failure."""
        try:
            resp = await self._call("getFile", file_id=file_id)
            if resp.get("ok"):
                file_path = resp.get("result", {}).get("file_path", "")
                if file_path:
                    return f"https://api.telegram.org/file/bot{self.bot_token}/{file_path}"
        except Exception:
            pass
        return None

    async def get_channel_info(self, chat_id: str) -> dict:
        """Get channel info."""
        return await self._call("getChat", chat_id=chat_id)

    async def close(self):
        await self.http.aclose()


video_bot_service = VideoBotService()
