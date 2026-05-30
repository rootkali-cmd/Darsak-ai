import asyncio
import logging
import random
from typing import Any
from supabase import create_async_client, AsyncClient
from postgrest.exceptions import APIError
from httpx import HTTPError, TimeoutException, Limits
from src.core.config import get_settings
from src.infrastructure.circuit_breaker import supabase_breaker

logger = logging.getLogger("darsak")
settings = get_settings()

SUPABASE_TIMEOUT = 15.0
SUPABASE_MAX_RETRIES = 2
SUPABASE_INITIAL_BACKOFF = 0.5

_client: AsyncClient | None = None
_client_lock = asyncio.Lock()


class SupabaseError(Exception):
    def __init__(self, message: str, original: Exception | None = None):
        super().__init__(message)
        self.original = original


async def get_supabase() -> AsyncClient:
    """Get or create the singleton Supabase client with connection pooling."""
    global _client
    if _client is not None:
        return _client
    
    async with _client_lock:
        if _client is not None:
            return _client
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise RuntimeError("Supabase credentials not configured")
        try:
            _client = await asyncio.wait_for(
                create_async_client(
                    settings.SUPABASE_URL,
                    settings.SUPABASE_SERVICE_ROLE_KEY,
                    options={"headers": {"X-Client-Info": "darsak-backend"}},
                ),
                timeout=10.0,
            )
            logger.info("Supabase client created")
        except asyncio.TimeoutError:
            raise SupabaseError("Failed to connect to Supabase (timeout)")
    return _client


async def _execute_with_retry(coro_factory, description: str = "Supabase operation"):
    """Execute Supabase operation with retry, timeout, and circuit breaker."""
    async def attempt():
        coro = coro_factory()
        return await asyncio.wait_for(coro, timeout=SUPABASE_TIMEOUT)
    
    last_error: Exception | None = None
    for attempt_num in range(SUPABASE_MAX_RETRIES + 1):
        try:
            return await supabase_breaker.call(attempt, f"{description} (attempt {attempt_num + 1})")
        except Exception as e:
            last_error = e
            if attempt_num < SUPABASE_MAX_RETRIES:
                backoff = SUPABASE_INITIAL_BACKOFF * (2 ** attempt_num) + random.uniform(0, 0.1)
                logger.warning("Supabase retry %d/%d for '%s' in %.2fs: %s",
                              attempt_num + 1, SUPABASE_MAX_RETRIES, description, backoff, e)
                await asyncio.sleep(backoff)
            else:
                logger.error("Supabase failed after %d retries for '%s': %s",
                            SUPABASE_MAX_RETRIES + 1, description, e)
    
    msg = f"Database operation '{description}' failed after {SUPABASE_MAX_RETRIES + 1} attempts"
    if isinstance(last_error, asyncio.TimeoutError):
        raise SupabaseError(f"{msg}: timeout after {SUPABASE_TIMEOUT}s")
    if isinstance(last_error, APIError):
        e = last_error
        err_msg = e.message if hasattr(e, 'message') else str(e)
        raise SupabaseError(f"Database error: {err_msg}", original=e)
    if isinstance(last_error, (HTTPError, TimeoutException)):
        raise SupabaseError(f"Network error connecting to database: {last_error}", original=last_error)
    raise SupabaseError(msg, original=last_error)


class SupabaseRepository:
    def __init__(self, table_name: str):
        self.table_name = table_name
    
    async def _get_client(self) -> AsyncClient:
        return await get_supabase()
    
    async def insert(self, data: dict | list[dict]) -> dict:
        client = await self._get_client()
        result = await _execute_with_retry(
            lambda: client.table(self.table_name).insert(data).execute(),
            f"insert {self.table_name}",
        )
        if not result.data:
            raise SupabaseError(f"Insert into {self.table_name} returned no data")
        return result.data[0] if isinstance(result.data, list) else result.data
    
    async def select(self, filters: dict | None = None, limit: int = 50, offset: int = 0, order: str | None = None, count: str | None = None) -> list[dict]:
        client = await self._get_client()
        def build_query():
            q = client.table(self.table_name).select("*", count=count or "exact" if count else "exact")
            if filters:
                for key, value in filters.items():
                    q = q.eq(key, value)
            q = q.limit(limit).offset(offset)
            if order:
                q = q.order(order, desc=True)
            else:
                q = q.order("created_at", desc=True)
            return q
        
        result = await _execute_with_retry(
            lambda: build_query().execute(),
            f"select {self.table_name}",
        )
        return result.data
    
    async def search(self, filters: dict | None = None, text_search: dict[str, str] | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        """Select with case-insensitive text search on specific columns.
        
        text_search = {"column_name": "search_term", ...}
        Uses OR between columns, AND with filters.
        """
        client = await self._get_client()
        def build_query():
            from postgrest.base_request_builder import APIResponse
            q = client.table(self.table_name).select("*")
            if filters:
                for key, value in filters.items():
                    q = q.eq(key, value)
            if text_search:
                from functools import reduce
                import operator
                or_filters = []
                for column, term in text_search.items():
                    or_filters.append(f"{column}.ilike.*{term}*")
                if or_filters:
                    q = q.or_(",".join(or_filters))
            q = q.limit(limit).offset(offset).order("created_at", desc=True)
            return q
        
        result = await _execute_with_retry(
            lambda: build_query().execute(),
            f"search {self.table_name}",
        )
        return result.data
    
    async def select_one(self, filters: dict) -> dict | None:
        client = await self._get_client()
        def build_query():
            q = client.table(self.table_name).select("*")
            for key, value in filters.items():
                q = q.eq(key, value)
            return q
        result = await _execute_with_retry(
            lambda: build_query().limit(1).execute(),
            f"select_one {self.table_name}",
        )
        return result.data[0] if result.data else None
    
    async def update(self, filters: dict, data: dict) -> dict:
        client = await self._get_client()
        def build_query():
            q = client.table(self.table_name).update(data)
            for key, value in filters.items():
                q = q.eq(key, value)
            return q
        result = await _execute_with_retry(
            lambda: build_query().execute(),
            f"update {self.table_name}",
        )
        return result.data[0] if result.data else {}
    
    async def delete(self, filters: dict) -> bool:
        client = await self._get_client()
        def build_query():
            q = client.table(self.table_name).delete()
            for key, value in filters.items():
                q = q.eq(key, value)
            return q
        result = await _execute_with_retry(
            lambda: build_query().execute(),
            f"delete {self.table_name}",
        )
        return len(result.data) > 0
    
    async def count(self, filters: dict | None = None) -> int:
        client = await self._get_client()
        def build_query():
            q = client.table(self.table_name).select("*", count="exact")
            if filters:
                for key, value in filters.items():
                    q = q.eq(key, value)
            return q
        result = await _execute_with_retry(
            lambda: build_query().limit(1).execute(),
            f"count {self.table_name}",
        )
        return result.count or 0
