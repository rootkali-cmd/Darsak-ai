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
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    AI_TIMEOUT: int = 60

    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "google/gemini-2.0-flash-001"
    OPENROUTER_VISION_MODEL: str = "google/gemini-2.0-flash-001"

    SECRET_KEY: str = "change-me-in-production-use-openssl-rand"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
    ]

    LOG_LEVEL: str = "INFO"

    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_ID: str = ""

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "case_sensitive": True}


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    if not s.SECRET_KEY or s.SECRET_KEY == "change-me-in-production-use-openssl-rand":
        raise ValueError("SECRET_KEY must be set in environment. Use `openssl rand -hex 32` to generate one.")
    if not s.SUPABASE_URL or not s.SUPABASE_SERVICE_ROLE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment")
    return s
