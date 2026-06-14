"""
LLM configuration for agents
"""
import os
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_ollama import ChatOllama
from pydantic_settings import BaseSettings


class LLMSettings(BaseSettings):
    """LLM configuration from environment"""
    # OpenAI
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_MODEL: str = "gpt-4o"
    OPENAI_TEMPERATURE: float = 0.1
    
    # Ollama (local fallback)
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "codellama:13b"
    OLLAMA_TEMPERATURE: float = 0.1
    
    # CrewAI
    CREWAI_PROCESS: str = "sequential"  # sequential or hierarchical
    
    class Config:
        env_file = ".env"
        case_sensitive = True


_settings = LLMSettings()


def get_llm(
    model: Optional[str] = None,
    temperature: Optional[float] = None,
    use_local: bool = False,
    **kwargs
):
    """Get configured LLM instance"""
    
    if use_local or not _settings.OPENAI_API_KEY:
        return ChatOllama(
            base_url=_settings.OLLAMA_BASE_URL,
            model=model or _settings.OLLAMA_MODEL,
            temperature=temperature or _settings.OLLAMA_TEMPERATURE,
            **kwargs
        )
    
    return ChatOpenAI(
        api_key=_settings.OPENAI_API_KEY,
        model=model or _settings.OPENAI_MODEL,
        temperature=temperature or _settings.OPENAI_TEMPERATURE,
        **kwargs
    )


def get_llm_for_level(level: str, **kwargs):
    """Get specialized LLM for agent level"""
    # Different models/temperatures for different levels
    configs = {
        "architect": {"temperature": 0.2, "model": "gpt-4o"},
        "security": {"temperature": 0.1, "model": "gpt-4o"},
        "platform": {"temperature": 0.2, "model": "gpt-4o"},
        "backend": {"temperature": 0.1, "model": "gpt-4o"},
        "database": {"temperature": 0.1, "model": "gpt-4o"},
        "contract": {"temperature": 0.0, "model": "gpt-4o"},
        "code_review": {"temperature": 0.0, "model": "gpt-4o"},
        "testing": {"temperature": 0.1, "model": "gpt-4o"},
        "contract_test": {"temperature": 0.0, "model": "gpt-4o"},
    }
    
    config = configs.get(level.lower(), {})
    config.update(kwargs)
    return get_llm(**config)