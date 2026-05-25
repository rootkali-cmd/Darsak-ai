import asyncio
import logging
from typing import Any
from uuid import UUID
from supabase import create_async_client, AsyncClient
from postgrest.exceptions import APIError
from httpx import HTTPError, TimeoutException
from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()

_supabase_client: AsyncClient | None = None
SUPABASE_TIMEOUT = 15.0


class SupabaseError(Exception):
    def __init__(self, message: str, original: Exception | None = None):
        super().__init__(message)
        self.original = original


async def get_supabase() -> AsyncClient:
    global _supabase_client
    if _supabase_client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise RuntimeError("Supabase credentials not configured")
        try:
            _supabase_client = await asyncio.wait_for(
                create_async_client(
                    settings.SUPABASE_URL,
                    settings.SUPABASE_SERVICE_ROLE_KEY,
                ),
                timeout=5.0,
            )
        except asyncio.TimeoutError:
            raise SupabaseError("Failed to connect to Supabase (timeout)")
    return _supabase_client


async def _execute_with_timeout(coro, description: str = "Supabase operation"):
    try:
        return await asyncio.wait_for(coro, timeout=SUPABASE_TIMEOUT)
    except asyncio.TimeoutError:
        logger.error("Supabase timeout: %s", description)
        raise SupabaseError(f"Database operation timed out after {SUPABASE_TIMEOUT}s")
    except APIError as e:
        logger.error("Supabase API error (%s): %s", description, e)
        msg = e.message if hasattr(e, 'message') else str(e)
        raise SupabaseError(f"Database error: {msg}", original=e)
    except (HTTPError, TimeoutException) as e:
        logger.error("Supabase HTTP error (%s): %s", description, e)
        raise SupabaseError("Network error connecting to database", original=e)


class SupabaseRepository:
    def __init__(self, table_name: str):
        self.table_name = table_name

    async def _get_client(self) -> AsyncClient:
        return await get_supabase()

    async def insert(self, data: dict) -> dict:
        client = await self._get_client()
        result = await _execute_with_timeout(
            client.table(self.table_name).insert(data).execute(),
            f"insert into {self.table_name}",
        )
        if not result.data:
            raise SupabaseError(f"Insert into {self.table_name} returned no data")
        return result.data[0] if isinstance(result.data, list) else result.data

    async def select(self, filters: dict | None = None, limit: int = 50, offset: int = 0, order: str | None = None) -> list[dict]:
        client = await self._get_client()
        query = client.table(self.table_name).select("*")
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        query = query.limit(limit).offset(offset)
        if order:
            query = query.order(order, desc=True)
        else:
            query = query.order("created_at", desc=True)
        result = await _execute_with_timeout(
            query.execute(),
            f"select from {self.table_name}",
        )
        return result.data

    async def select_one(self, filters: dict) -> dict | None:
        client = await self._get_client()
        query = client.table(self.table_name).select("*")
        for key, value in filters.items():
            query = query.eq(key, value)
        result = await _execute_with_timeout(
            query.limit(1).execute(),
            f"select_one from {self.table_name}",
        )
        return result.data[0] if result.data else None

    async def update(self, filters: dict, data: dict) -> dict:
        client = await self._get_client()
        query = client.table(self.table_name).update(data)
        for key, value in filters.items():
            query = query.eq(key, value)
        result = await _execute_with_timeout(
            query.execute(),
            f"update {self.table_name}",
        )
        return result.data[0] if result.data else {}

    async def delete(self, filters: dict) -> bool:
        client = await self._get_client()
        query = client.table(self.table_name).delete()
        for key, value in filters.items():
            query = query.eq(key, value)
        result = await _execute_with_timeout(
            query.execute(),
            f"delete from {self.table_name}",
        )
        return len(result.data) > 0

    async def count(self, filters: dict | None = None) -> int:
        client = await self._get_client()
        query = client.table(self.table_name).select("*", count="exact")
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        result = await _execute_with_timeout(
            query.execute(),
            f"count {self.table_name}",
        )
        return result.count or 0
