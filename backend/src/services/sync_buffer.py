import asyncio
import json
import logging
from urllib.parse import urlparse
from datetime import datetime, timezone, timedelta
from uuid import UUID, uuid4

import redis.asyncio as aioredis

from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()


class SyncBuffer:
    def __init__(self):
        self.redis: aioredis.Redis | None = None
        self._connected = False
        self._processed_operations: set[str] = set()

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

    async def is_operation_processed(self, operation_id: str) -> bool:
        if not operation_id:
            return False
        if operation_id in self._processed_operations:
            return True
        if not self._connected or not self.redis:
            return False
        exists = await self.redis.sismember("processed_operations", operation_id)
        if exists:
            self._processed_operations.add(operation_id)
        return bool(exists)

    async def mark_operation_processed(self, operation_id: str, ttl_days: int = 7):
        if not self._connected or not self.redis:
            self._processed_operations.add(operation_id)
            return
        await self.redis.sadd("processed_operations", operation_id)
        await self.redis.expire("processed_operations", int(timedelta(days=ttl_days).total_seconds()))
        self._processed_operations.add(operation_id)

    async def push_pending(self, teacher_id: str, payload: dict, operation_id: str | None = None) -> str:
        if not self._connected or not self.redis:
            return "redis_unavailable"
        key = f"sync:queue:{teacher_id}"
        item = json.dumps({
            "operation_id": operation_id or str(uuid4()),
            "data": payload,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "retry_count": 0,
            "max_retries": 3,
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
            parsed = json.loads(item)
            op_id = parsed.get("operation_id", "")
            if op_id and await self.is_operation_processed(op_id):
                continue
            items.append(parsed)
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

    async def push_to_dead_letter(self, teacher_id: str, item: dict, error: str):
        if not self._connected or not self.redis:
            return
        key = f"sync:dead_letter:{teacher_id}"
        item["error"] = error
        item["failed_at"] = datetime.now(timezone.utc).isoformat()
        await self.redis.lpush(key, json.dumps(item))
        await self.redis.expire(key, int(timedelta(days=30).total_seconds()))

    async def recover_dead_letters(self, teacher_id: str) -> list[dict]:
        if not self._connected or not self.redis:
            return []
        key = f"sync:dead_letter:{teacher_id}"
        items = []
        while True:
            item = await self.redis.rpop(key)
            if not item:
                break
            items.append(json.loads(item))
        return items

    async def cleanup_old_items(self, max_age_days: int = 30):
        if not self._connected or not self.redis:
            return
        cursor = 0
        pattern = "sync:queue:*"
        while True:
            cursor, keys = await self.redis.scan(cursor, match=pattern, count=100)
            for key in keys:
                ttl = await self.redis.ttl(key)
                if ttl < 0:
                    cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)
                    queue_length = await self.redis.llen(key)
                    for _ in range(queue_length):
                        item = await self.redis.lindex(key, -1)
                        if not item:
                            break
                        parsed = json.loads(item)
                        ts = parsed.get("timestamp", "")
                        try:
                            item_time = datetime.fromisoformat(ts)
                            if item_time < cutoff:
                                await self.redis.rpop(key)
                            else:
                                break
                        except (ValueError, TypeError):
                            await self.redis.rpop(key)
            if cursor == 0:
                break


sync_buffer = SyncBuffer()
