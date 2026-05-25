import logging
from src.core.config import get_settings
from src.core.security.supabase_repo import get_supabase as get_async_supabase, AsyncClient

logger = logging.getLogger("darsak")
settings = get_settings()


async def get_supabase() -> AsyncClient:
    return await get_async_supabase()
