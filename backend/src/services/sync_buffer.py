import asyncio
import json
import logging
from urllib.parse import urlparse
from datetime import datetime, timezone, timedelta
from uuid import UUID

import redis.asyncio as aioredis

from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()


class SyncBuffer:
    def __init__(self):
        self.redis: aioredis.Redis | None = None
        self._connected = False

    async def connect(self):
        try:
            self.redis = aioredis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                max_connections=20,
                socket_connect_timeout=3,
                socket_timeout=3,
            )
            await asyncio.wait_for(self.redis.ping(), timeout=5)
            self._connected = True
            safe_url = urlparse(settings.REDIS_URL)._replace(netloc="***:***@" + urlparse(settings.REDIS_URL).hostname).geturl() if "@" in settings.REDIS_URL else settings.REDIS_URL
            logger.info("Connected to Redis at %s", safe_url)
        except Exception as e:
            logger.warning("Redis connection failed, sync buffer disabled: %s", e)
            self._connected = False

    async def push_pending(self, teacher_id: str, payload: dict) -> str:
        if not self._connected or not self.redis:
            return "redis_unavailable"
        key = f"sync:queue:{teacher_id}"
        item = json.dumps({
            "data": payload,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "retry_count": 0,
        })
        await self.redis.lpush(key, item)
        await self.redis.expire(key, int(timedelta(days=30).total_seconds()))
        return key

    async def pull_pending(self, teacher_id: str, limit: int = 50) -> list[dict]:
        if not self._connected or not self.redis:
            return []
        key = f"sync:queue:{teacher_id}"
        items = []
        for _ in range(limit):
            item = await self.redis.rpop(key)
            if not item:
                break
            items.append(json.loads(item))
        return items

    async def get_queue_length(self, teacher_id: str) -> int:
        if not self._connected or not self.redis:
            return 0
        key = f"sync:queue:{teacher_id}"
        return await self.redis.llen(key)

    async def remove_items(self, teacher_id: str, count: int):
        if not self._connected or not self.redis:
            return
        key = f"sync:queue:{teacher_id}"
        await self.redis.ltrim(key, 0, -count - 1)


sync_buffer = SyncBuffer()
