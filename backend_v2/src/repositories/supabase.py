import asyncio
from typing import Any

from supabase import AsyncClient

from src.core.config import get_settings

settings = get_settings()


class SupabaseRepository:
    def __init__(self, table_name: str):
        self.table_name = table_name
        self.client = AsyncClient(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_SERVICE_ROLE_KEY,
        )

    async def _execute_with_retry(self, operation, *args, **kwargs):
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                return await operation(*args, **kwargs)
            except Exception:
                if attempt == max_attempts:
                    raise
                await asyncio.sleep(2 ** attempt)
        return None

    async def _await_response(self, request):
        return await request

    async def insert(self, data: dict) -> dict:
        request = self.client.table(self.table_name).insert(data).execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.data[0] if response.data else {}

    async def select(self, filters: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        query = self.client.table(self.table_name).select("*").range(offset, offset + limit - 1)
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.data if response.data else []

    async def select_one(self, filters: dict) -> dict | None:
        query = self.client.table(self.table_name).select("*").limit(1)
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.data[0] if response.data else None

    async def update(self, filters: dict, data: dict) -> dict:
        query = self.client.table(self.table_name).update(data)
        for key, value in filters.items():
            query = query.eq(key, value)
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.data[0] if response.data else {}

    async def delete(self, filters: dict) -> bool:
        query = self.client.table(self.table_name).delete()
        for key, value in filters.items():
            query = query.eq(key, value)
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return bool(response.data)

    async def count(self, filters: dict | None = None) -> int:
        query = self.client.table(self.table_name).select("*", count="exact").limit(0)
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.count or 0

    async def search(self, filters: dict | None = None, text_search: dict | None = None, limit: int = 50, offset: int = 0) -> list[dict]:
        query = self.client.table(self.table_name).select("*").range(offset, offset + limit - 1)
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        if text_search:
            or_parts = [f"{field}.ilike.%{value}%" for field, value in text_search.items()]
            query = query.or_(",".join(or_parts))
        request = query.execute()
        response = await self._execute_with_retry(self._await_response, request)
        return response.data if response.data else []
