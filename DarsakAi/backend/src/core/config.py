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

    SUBSCRIPTION_SECRET_KEY: str = "d4r54k-5ubscr1pt10n-s1gn3d-k3y-2025-53cur3"

    # Plan student limits
    PLAN_BASIC_MAX_STUDENTS: int = 100
    PLAN_PRO_MAX_STUDENTS: int = 400
    PLAN_PREMIUM_MAX_STUDENTS: int = -1  # Unlimited
    PLAN_ENTERPRISE_MAX_STUDENTS: int = -1  # Unlimited

    # Plan AI request limits per month
    PLAN_BASIC_AI_LIMIT: int = 5
    PLAN_PRO_AI_LIMIT: int = 30
    PLAN_PREMIUM_AI_LIMIT: int = -1  # Unlimited
    PLAN_ENTERPRISE_AI_LIMIT: int = -1  # Unlimited

    # Plan video storage limits (bytes)
    PLAN_BASIC_STORAGE_LIMIT: int = 2 * 1024 * 1024 * 1024   # 2GB
    PLAN_PRO_STORAGE_LIMIT: int = 6 * 1024 * 1024 * 1024      # 6GB
    PLAN_ENTERPRISE_STORAGE_LIMIT: int = -1                     # Unlimited

    SECRET_KEY: str = "change-me-in-production-use-openssl-rand"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 days — permanent login
    REFRESH_TOKEN_EXPIRE_DAYS: int = 365  # 1 year

    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
    ]

    LOG_LEVEL: str = "INFO"

    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_ID: str = ""
    VIDEO_TELEGRAM_BOT_TOKEN: str = ""

    # Firebase Cloud Messaging
    FIREBASE_SERVICE_ACCOUNT_JSON: str = ""  # JSON string of service account credentials
    FIREBASE_SERVICE_ACCOUNT_PATH: str = ""  # Path to service account JSON file

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "case_sensitive": True}


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    if not s.SECRET_KEY or s.SECRET_KEY == "change-me-in-production-use-openssl-rand":
        raise ValueError("SECRET_KEY must be set in environment. Use `openssl rand -hex 32` to generate one.")
    if not s.SUPABASE_URL or not s.SUPABASE_SERVICE_ROLE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment")
    return s
