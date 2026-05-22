import os
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from src.core.config import get_settings

settings = get_settings()

_use_small_pool = os.environ.get("VERCEL") == "1"

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    pool_size=2 if _use_small_pool else 20,
    max_overflow=2 if _use_small_pool else 10,
    pool_pre_ping=True,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
