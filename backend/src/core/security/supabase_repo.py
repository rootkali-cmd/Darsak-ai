import logging
from typing import Any
from uuid import UUID
from supabase import create_client, Client
from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()

_supabase_client: Client | None = None


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise RuntimeError("Supabase credentials not configured")
        _supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    return _supabase_client


class SupabaseRepository:
    def __init__(self, table_name: str):
        self.table_name = table_name
        self.client = get_supabase()

    async def insert(self, data: dict) -> dict:
        result = self.client.table(self.table_name).insert(data).execute()
        return result.data[0] if result.data else {}

    async def select(self, filters: dict | None = None, limit: int = 50, offset: int = 0, order: str | None = None) -> list[dict]:
        query = self.client.table(self.table_name).select("*")
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        query = query.limit(limit).offset(offset)
        if order:
            query = query.order(order, desc=True)
        else:
            query = query.order("created_at", desc=True)
        result = query.execute()
        return result.data

    async def select_one(self, filters: dict) -> dict | None:
        query = self.client.table(self.table_name).select("*")
        for key, value in filters.items():
            query = query.eq(key, value)
        result = query.limit(1).execute()
        return result.data[0] if result.data else None

    async def update(self, filters: dict, data: dict) -> dict:
        query = self.client.table(self.table_name).update(data)
        for key, value in filters.items():
            query = query.eq(key, value)
        result = query.execute()
        return result.data[0] if result.data else {}

    async def delete(self, filters: dict) -> bool:
        query = self.client.table(self.table_name).delete()
        for key, value in filters.items():
            query = query.eq(key, value)
        result = query.execute()
        return len(result.data) > 0

    async def count(self, filters: dict | None = None) -> int:
        query = self.client.table(self.table_name).select("*", count="exact")
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        result = query.execute()
        return result.count or 0
