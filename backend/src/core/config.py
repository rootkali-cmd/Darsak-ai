from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    PROJECT_NAME: str = "DarsakAI Hub"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api"

    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/darsakdb"
    DATABASE_URL_SYNC: str = "postgresql://user:password@localhost:5432/darsakdb"

    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""

    REDIS_URL: str = "redis://localhost:6379/0"

    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    AI_TIMEOUT: int = 30

    SECRET_KEY: str = "change-me-in-production-use-openssl-rand"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
    ]

    LOG_LEVEL: str = "INFO"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "case_sensitive": True}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
