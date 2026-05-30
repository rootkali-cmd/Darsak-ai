"""In-memory LRU cache with TTL support.

Used for hot data like user profiles to reduce Supabase round-trips.
"""
import time
import asyncio
from typing import Any
from collections import OrderedDict


class CacheEntry:
    def __init__(self, value: Any, ttl_seconds: float):
        self.value = value
        self.expires_at = time.time() + ttl_seconds
        self.access_count = 0
    
    @property
    def is_expired(self) -> bool:
        return time.time() > self.expires_at


class LRUCache:
    """Thread-safe (async-safe) LRU cache with TTL.
    
    Uses OrderedDict for O(1) LRU eviction.
    """
    
    def __init__(self, max_size: int = 1000, default_ttl: float = 300.0):
        self._max_size = max_size
        self._default_ttl = default_ttl
        self._cache: OrderedDict[str, CacheEntry] = OrderedDict()
        self._lock = asyncio.Lock()
        self._hits = 0
        self._misses = 0
    
    async def get(self, key: str) -> Any | None:
        async with self._lock:
            entry = self._cache.get(key)
            if entry is None:
                self._misses += 1
                return None
            if entry.is_expired:
                del self._cache[key]
                self._misses += 1
                return None
            # Move to end (most recently used)
            self._cache.move_to_end(key)
            entry.access_count += 1
            self._hits += 1
            return entry.value
    
    async def set(self, key: str, value: Any, ttl: float | None = None) -> None:
        async with self._lock:
            ttl = ttl or self._default_ttl
            if key in self._cache:
                self._cache.move_to_end(key)
            self._cache[key] = CacheEntry(value, ttl)
            # Evict oldest if over limit
            while len(self._cache) > self._max_size:
                self._cache.popitem(last=False)
    
    async def delete(self, key: str) -> None:
        async with self._lock:
            self._cache.pop(key, None)
    
    async def invalidate_pattern(self, pattern: str) -> None:
        """Delete all keys containing a substring."""
        async with self._lock:
            keys_to_delete = [k for k in self._cache if pattern in k]
            for k in keys_to_delete:
                del self._cache[k]
    
    @property
    async def stats(self) -> dict:
        async with self._lock:
            total = self._hits + self._misses
            hit_rate = self._hits / total if total > 0 else 0
            return {
                "size": len(self._cache),
                "max_size": self._max_size,
                "hits": self._hits,
                "misses": self._misses,
                "hit_rate": round(hit_rate, 3),
            }


# Global cache instances
user_cache = LRUCache(max_size=500, default_ttl=300.0)    # 5 min TTL for users
student_cache = LRUCache(max_size=1000, default_ttl=60.0)  # 1 min TTL for students
cache = LRUCache(max_size=2000, default_ttl=300.0)         # General cache
