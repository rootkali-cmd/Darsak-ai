from sqlalchemy.ext.asyncio import create_async_engine, AsyncEngine
from sqlalchemy.orm import DeclarativeBase
from src.core.config import get_settings

settings = get_settings()

_engine: AsyncEngine | None = None


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        url = settings.DATABASE_URL
        if not url:
            url = settings.SUPABASE_URL.replace("https://", "postgresql+asyncpg://postgres:") + f"@db.{settings.SUPABASE_URL.split('//')[1].split('.')[0]}.supabase.co:5432/postgres"
        _engine = create_async_engine(url, echo=False, pool_size=5, max_overflow=10)
    return _engine


class Base(DeclarativeBase):
    pass
