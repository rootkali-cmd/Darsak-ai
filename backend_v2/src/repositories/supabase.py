import asyncio
import re
from typing import Any
from sqlalchemy import text
from src.core.database import get_engine
from src.core.config import get_settings

settings = get_settings()

SAFE_IDENTIFIER = re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$')


def _validate_identifier(name: str) -> str:
    if not SAFE_IDENTIFIER.match(name):
        raise ValueError(f"Invalid identifier: {name}")
    return name


class SupabaseRepository:
    def __init__(self, table_name: str):
        self.table_name = _validate_identifier(table_name)

    async def _execute(self, query, params=None):
        engine = get_engine()
        async with engine.begin() as conn:
            result = await conn.execute(text(query), params or {})
            rows = result.fetchall()
            if rows:
                return [dict(zip(result.keys(), row)) for row in rows]
            return []

    async def _execute_single(self, query, params=None):
        engine = get_engine()
        async with engine.begin() as conn:
            result = await conn.execute(text(query), params or {})
            row = result.fetchone()
            if row:
                return dict(zip(result.keys(), row))
            return None

    def _build_select(self, filters: dict | None = None, order_desc: bool = True, limit: int = 50, offset: int = 0):
        query = f"SELECT * FROM {self.table_name}"
        params = {}
        if filters:
            conditions = []
            for k, v in filters.items():
                _validate_identifier(k)
                param_key = f"p_{k}"
                conditions.append(f"{k} = :{param_key}")
                params[param_key] = v
            query += " WHERE " + " AND ".join(conditions)
        if order_desc:
            query += " ORDER BY created_at DESC"
        query += f" LIMIT :limit OFFSET :offset"
        params["limit"] = limit
        params["offset"] = offset
        return query, params

    async def insert(self, data: dict) -> dict:
        engine = get_engine()
        for k in data.keys():
            _validate_identifier(k)
        columns = ", ".join(data.keys())
        placeholders = ", ".join([f":{k}" for k in data.keys()])
        returning = "id, " + ", ".join(data.keys())
        query = f"INSERT INTO {self.table_name} ({columns}) VALUES ({placeholders}) RETURNING {returning}"
        async with engine.begin() as conn:
            result = await conn.execute(text(query), data)
            row = result.fetchone()
            if row:
                return dict(zip(result.keys(), row))
        raise Exception(f"Insert into {self.table_name} returned no data")

    async def select(self, filters: dict | None = None, limit: int = 50, offset: int = 0):
        query, params = self._build_select(filters, limit=limit, offset=offset)
        return await self._execute(query, params)

    async def select_one(self, filters: dict):
        query, params = self._build_select(filters, limit=1, offset=0)
        return await self._execute_single(query, params)

    async def update(self, filters: dict, data: dict):
        engine = get_engine()
        for k in list(data.keys()) + list(filters.keys()):
            _validate_identifier(k)
        set_parts = [f"{k} = :s_{k}" for k in data.keys()]
        cond_parts = [f"{k} = :c_{k}" for k in filters.keys()]
        params = {}
        for k, v in data.items():
            params[f"s_{k}"] = v
        for k, v in filters.items():
            params[f"c_{k}"] = v
        returning = ", ".join(data.keys())
        query = f"UPDATE {self.table_name} SET {', '.join(set_parts)} WHERE {' AND '.join(cond_parts)} RETURNING *"
        async with engine.begin() as conn:
            result = await conn.execute(text(query), params)
            row = result.fetchone()
            if row:
                return dict(zip(result.keys(), row))
        return {}

    async def delete(self, filters: dict) -> bool:
        engine = get_engine()
        for k in filters.keys():
            _validate_identifier(k)
        cond_parts = [f"{k} = :c_{k}" for k in filters.keys()]
        params = {f"c_{k}": v for k, v in filters.items()}
        query = f"DELETE FROM {self.table_name} WHERE {' AND '.join(cond_parts)}"
        async with engine.begin() as conn:
            result = await conn.execute(text(query), params)
            return result.rowcount > 0
        return False

    async def count(self, filters: dict | None = None) -> int:
        engine = get_engine()
        query = f"SELECT COUNT(*) as cnt FROM {self.table_name}"
        params = {}
        if filters:
            conditions = []
            for k, v in filters.items():
                _validate_identifier(k)
                conditions.append(f"{k} = :p_{k}")
                params[f"p_{k}"] = v
            query += " WHERE " + " AND ".join(conditions)
        async with engine.begin() as conn:
            result = await conn.execute(text(query), params)
            row = result.fetchone()
            return row[0] if row else 0

    async def search(self, filters: dict | None = None, text_search: dict | None = None, limit: int = 50, offset: int = 0):
        query = f"SELECT * FROM {self.table_name}"
        params = {}
        all_conditions = []
        if filters:
            for k, v in filters.items():
                _validate_identifier(k)
                all_conditions.append(f"{k} = :p_{k}")
                params[f"p_{k}"] = v
        if text_search:
            search_conditions = []
            for field, val in text_search.items():
                _validate_identifier(field)
                search_conditions.append(f"{field} ILIKE :s_{field}")
                escaped = val.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
                params[f"s_{field}"] = f"%{escaped}%"
            if search_conditions:
                all_conditions.append("(" + " OR ".join(search_conditions) + ")")
        if all_conditions:
            query += " WHERE " + " AND ".join(all_conditions)
        query += " ORDER BY created_at DESC"
        query += f" LIMIT :limit OFFSET :offset"
        params["limit"] = limit
        params["offset"] = offset
        return await self._execute(query, params)
