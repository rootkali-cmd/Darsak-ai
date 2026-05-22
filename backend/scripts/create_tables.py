import asyncio
import sys
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from sqlalchemy.ext.asyncio import create_async_engine
from src.core.config import get_settings
from src.models import (
    User, Student, Group, Attendance, Grade, Invoice, EncryptedPayload, AuditLog,
)
from src.utils.database import Base

settings = get_settings()

print("🔌 Connecting to Supabase PostgreSQL...")
print(f"   Host: {settings.DATABASE_URL.split('@')[1].split('/')[0]}")

engine = create_async_engine(
    settings.DATABASE_URL_SYNC.replace("postgresql://", "postgresql+asyncpg://"),
    echo=True,
)


async def create_tables():
    async with engine.begin() as conn:
        print("\n📋 Creating tables...")
        await conn.run_sync(Base.metadata.create_all)
        print("✅ All tables created successfully!")

        result = await conn.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name;
        """)
        tables = result.fetchall()
        print(f"\n📊 Tables in database ({len(tables)}):")
        for t in tables:
            print(f"   ✓ {t[0]}")


async def main():
    try:
        await create_tables()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        raise
    finally:
        await engine.dispose()


asyncio.run(main())
