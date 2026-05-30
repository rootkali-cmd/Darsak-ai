import os
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from src.core.config import get_settings

settings = get_settings()

_use_small_pool = os.environ.get("VERCEL") == "1"
_engine = None


def get_engine():
    """Lazy engine initialization — avoids import-time DB connection.
    Only creates the engine on first access, allowing apps without DATABASE_URL
    (e.g., Supabase-only installations) to import this module safely.
    """
    global _engine
    if _engine is None:
        if not settings.DATABASE_URL:
            raise RuntimeError(
                "DATABASE_URL not configured. Set it in .env or environment."
            )
        _engine = create_async_engine(
            settings.DATABASE_URL,
            echo=False,
            pool_size=2 if _use_small_pool else 20,
            max_overflow=2 if _use_small_pool else 10,
            pool_pre_ping=True,
        )
    return _engine


def get_session_factory():
    return async_sessionmaker(
        get_engine(),
        class_=AsyncSession,
        expire_on_commit=False,
    )


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
