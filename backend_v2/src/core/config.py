from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    PROJECT_NAME: str = "DarsakAI Hub v2"
    VERSION: str = "2.0.0"
    API_V1_PREFIX: str = "/api/v1"

    SECRET_KEY: str = "bf58eb6d26b0cdc2559a5e0ff000867509042c189dcc5a873726c4be86800600fcb009a89d82edb5b04556cba0ed38b5d41ace1f7783d03690c146878315b590"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200
    REFRESH_TOKEN_EXPIRE_DAYS: int = 365

    SUPABASE_URL: str = "https://fmoqdezqbpefptyyzfvw.supabase.co"
    SUPABASE_SERVICE_ROLE_KEY: str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtb3FkZXpxYnBlZnB0eXl6ZnZ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTA0NDE4OSwiZXhwIjoyMDk0NjIwMTg5fQ.6bJW4QIEPH9dpjFpQ2bFr9_m539JhgG0IhZ4QXCF9LI"

    DATABASE_URL: str = "postgresql+asyncpg://postgres.fmoqdezqbpefptyyzfvw:Kaliroot200@db.fmoqdezqbpefptyyzfvw.supabase.co:5432/postgres"

    LOG_LEVEL: str = "INFO"
    ENVIRONMENT: str = "development"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "case_sensitive": True, "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
