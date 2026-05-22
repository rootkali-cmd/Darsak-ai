import logging
from supabase import create_client, Client
from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()

supabase_client: Client | None = None


def get_supabase() -> Client:
    global supabase_client
    if supabase_client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            logger.warning("Supabase credentials not configured, using local DB only")
            return None
        supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
        logger.info("Supabase client initialized for %s", settings.SUPABASE_URL)
    return supabase_client
