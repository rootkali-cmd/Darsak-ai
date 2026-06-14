"""Distributed rate limiter with Redis backend or in-memory fallback.

Uses a sliding window algorithm with automatic key expiration.
Safe for multi-worker and multi-instance deployments.
"""
import asyncio
import time
import logging
from typing import Tuple
from collections import defaultdict

logger = logging.getLogger("darsak")

# Try to use Redis; fallback to in-memory with TTL cleanup
REDIS_AVAILABLE = False
try:
    import redis.asyncio as aioredis
    REDIS_AVAILABLE = True
except ImportError:
    pass


class InMemoryRateLimiter:
    """Process-local rate limiter with automatic TTL cleanup.
    
    Not distributed-safe, but handles single-worker setups.
    Cleans up expired entries every 60s to prevent memory leaks.
    """
    
    def __init__(self, window: int = 60, cleanup_interval: int = 60):
        self._store: dict[Tuple[str, str], list[float]] = defaultdict(list)
        self._window = window
        self._cleanup_interval = cleanup_interval
        self._last_cleanup = time.time()
        self._lock = asyncio.Lock()
    
    async def is_allowed(
        self,
        key: Tuple[str, str],
        max_requests: int,
    ) -> bool:
        async with self._lock:
            self._maybe_cleanup()
            now = time.time()
            requests_in_window = [
                t for t in self._store[key] if now - t < self._window
            ]
            if len(requests_in_window) >= max_requests:
                return False
            self._store[key] = requests_in_window
            self._store[key].append(now)
            return True
    
    def _maybe_cleanup(self):
        now = time.time()
        if now - self._last_cleanup < self._cleanup_interval:
            return
        # Remove all keys with no active requests
        expired_keys = [
            k for k, timestamps in self._store.items()
            if not any(now - t < self._window for t in timestamps)
        ]
        for k in expired_keys:
            del self._store[k]
        self._last_cleanup = now
        logger.debug("Rate limiter cleanup: removed %d expired keys", len(expired_keys))


class RedisRateLimiter:
    """Distributed rate limiter backed by Redis.
    
    Uses Redis sorted sets (ZADD/ZREMRANGEBYSCORE) for atomic sliding window.
    """
    
    def __init__(self, redis_url: str, window: int = 60):
        self._redis: aioredis.Redis | None = None
        self._redis_url = redis_url
        self._window = window
        self._connected = False
    
    async def connect(self):
        try:
            self._redis = aioredis.from_url(
                self._redis_url,
                decode_responses=True,
                max_connections=20,
                socket_connect_timeout=3,
                socket_timeout=3,
            )
            await asyncio.wait_for(self._redis.ping(), timeout=5)
            self._connected = True
            logger.info("Rate limiter connected to Redis")
        except Exception as e:
            logger.warning("Redis rate limiter unavailable, falling back to memory: %s", e)
            self._connected = False
    
    async def is_allowed(
        self,
        key: Tuple[str, str],
        max_requests: int,
    ) -> bool:
        if not self._connected or not self._redis:
            return True  # Fail open if Redis is down
        
        redis_key = f"ratelimit:{key[0]}:{key[1]}"
        now = time.time()
        window_start = now - self._window
        pipe = self._redis.pipeline()
        
        # Remove old entries outside the window
        pipe.zremrangebyscore(redis_key, 0, int(window_start * 1000))
        # Count entries in current window
        pipe.zcard(redis_key)
        # Add current request with timestamp as score
        pipe.zadd(redis_key, {str(now): int(now * 1000)})
        # Set expiry on the key
        pipe.expire(redis_key, self._window + 1)
        
        _, count, _, _ = await pipe.execute()
        
        if count >= max_requests:
            # Roll back: remove the entry we just added
            await self._redis.zrem(redis_key, str(now))
            return False
        return True


class RateLimiter:
    """Unified rate limiter: tries Redis first, falls back to in-memory."""
    
    def __init__(self, redis_url: str | None = None, window: int = 60):
        self._redis_limiter: RedisRateLimiter | None = None
        self._memory_limiter = InMemoryRateLimiter(window=window)
        self._use_redis = False
        
        if redis_url and REDIS_AVAILABLE:
            self._redis_limiter = RedisRateLimiter(redis_url, window=window)
    
    async def connect(self):
        if self._redis_limiter:
            await self._redis_limiter.connect()
            self._use_redis = self._redis_limiter._connected
    
    async def is_allowed(
        self,
        key: Tuple[str, str],
        max_requests: int,
    ) -> bool:
        if self._use_redis and self._redis_limiter:
            return await self._redis_limiter.is_allowed(key, max_requests)
        return await self._memory_limiter.is_allowed(key, max_requests)


# Global instance (initialized in lifespan)
rate_limiter = RateLimiter()
