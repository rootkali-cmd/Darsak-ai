import secrets
import logging
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    PROJECT_NAME: str = "DarsakAI Hub"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api"

    DATABASE_URL: str = ""
    DATABASE_URL_SYNC: str = ""

    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""

    REDIS_URL: str = ""

    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.1-8b-instant"
    GROQ_VISION_MODEL: str = "llama-3.2-11b-vision-preview"
    AI_TIMEOUT: int = 60

    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "deepseek/deepseek-v4-flash"
    OPENROUTER_VISION_MODEL: str = "google/gemini-2.0-flash-001"

    # OpenMAIC access code (shared secret for student auth tokens)
    ACCESS_CODE: str = "darsak-openmaic-secret"

    # Plan student limits
    PLAN_BASIC_MAX_STUDENTS: int = 100
    PLAN_PRO_MAX_STUDENTS: int = 400
    PLAN_PREMIUM_MAX_STUDENTS: int = 1000
    PLAN_GOLDEN_MAX_STUDENTS: int = 40000

    # Plan AI request limits per day
    PLAN_BASIC_AI_LIMIT: int = 5
    PLAN_PRO_AI_LIMIT: int = 10
    PLAN_PREMIUM_AI_LIMIT: int = 20
    PLAN_GOLDEN_AI_LIMIT: int = 20

    # Plan video storage limits (bytes)
    PLAN_BASIC_STORAGE_LIMIT: int = 15 * 1024 * 1024 * 1024       # 15GB
    PLAN_PRO_STORAGE_LIMIT: int = 60 * 1024 * 1024 * 1024          # 60GB
    PLAN_PREMIUM_STORAGE_LIMIT: int = 200 * 1024 * 1024 * 1024     # 200GB
    PLAN_GOLDEN_STORAGE_LIMIT: int = 2 * 1024 * 1024 * 1024 * 1024 # 2TB

    # Plan assistant limits
    PLAN_BASIC_MAX_ASSISTANTS: int = 0
    PLAN_PRO_MAX_ASSISTANTS: int = 2
    PLAN_PREMIUM_MAX_ASSISTANTS: int = 5
    PLAN_GOLDEN_MAX_ASSISTANTS: int = 25

    # Plan AI exam generation limits per month
    PLAN_BASIC_MAX_AI_EXAMS: int = 5
    PLAN_PRO_MAX_AI_EXAMS: int = 15
    PLAN_PREMIUM_MAX_AI_EXAMS: int = 20
    PLAN_GOLDEN_MAX_AI_EXAMS: int = 20

    # Plan AI grading limits per month (number of papers)
    PLAN_BASIC_MAX_AI_GRADING: int = 100
    PLAN_PRO_MAX_AI_GRADING: int = 500
    PLAN_PREMIUM_MAX_AI_GRADING: int = 2000
    PLAN_GOLDEN_MAX_AI_GRADING: int = 25000

    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30  # 30 minutes
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7  # 7 days

    CORS_ORIGINS: list[str] = [
        "https://localhost:3000",
        "https://localhost:8000",
    ]

    LOG_LEVEL: str = "INFO"

    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_ID: str = ""
    VIDEO_TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_WEBHOOK_SECRET: str = ""

    ADMIN_EMAIL: str = ""
    ADMIN_PASSWORD: str = ""

    # Cloudflare R2 Storage
    R2_ACCOUNT_ID: str = ""
    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET_NAME: str = "darsak-media"

    # Payout Telegram Bot (reuses existing TELEGRAM_BOT_TOKEN by default)
    PAYOUT_BOT_TOKEN: str = ""
    PAYOUT_ADMIN_CHAT_ID: str = ""

    # Student Telegram Bot
    STUDENT_BOT_TOKEN: str = ""

    # AES Encryption (reuses existing AES_ENCRYPTION_KEY in crypto_utils)
    # HMAC key is already in HMAC_SECRET_KEY env var

    # API Versioning
    API_V2_PREFIX: str = "/api/v2"

    # Redis Cache TTLs
    CACHE_TTL_AUTH: int = 1800
    CACHE_TTL_SUBSCRIPTION: int = 60
    CACHE_TTL_DASHBOARD: int = 30
    CACHE_TTL_STUDENT: int = 60
    CACHE_TTL_WALLET: int = 10

    # Rate Limiting (production)
    RATE_LIMIT_NORMAL: int = 100      # requests per minute for general endpoints
    RATE_LIMIT_AUTH: int = 10         # requests per minute for auth endpoints
    RATE_LIMIT_FINANCIAL: int = 5     # requests per minute for wallet/payout
    RATE_LIMIT_UPLOAD: int = 10       # requests per minute for file uploads
    RATE_LIMIT_BAN_THRESHOLD: int = 50  # consecutive violations = IP ban
    RATE_LIMIT_BAN_MINUTES: int = 15    # ban duration in minutes

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "case_sensitive": True}


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    if not s.SECRET_KEY:
        s.SECRET_KEY = secrets.token_hex(32)
        logging.warning(
            "SECURITY WARNING: SECRET_KEY not set in environment. Generated a random key. "
            "Tokens will be invalidated on restart. Set SECRET_KEY env var for production."
        )
    if not s.SUPABASE_URL or not s.SUPABASE_SERVICE_ROLE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment")
    return s
