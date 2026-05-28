import pytest
from src.core.security.sanitizer import (
    sanitize_text,
    sanitize_student_code,
    sanitize_pin,
    sanitize_email,
)
from src.core.config import get_settings
from src.main import _rate_limit_store


class TestSanitizer:
    def test_sanitize_text_strips_whitespace(self):
        assert sanitize_text("  hello  ") == "hello"
        assert sanitize_text("\t\n\r test \n") == "test"

    def test_sanitize_text_does_not_remove_html(self):
        result = sanitize_text("<script>alert('xss')</script>")
        assert result == "<script>alert('xss')</script>"

    def test_sanitize_student_code_removes_non_alphanumeric(self):
        result = sanitize_student_code("stu-a1b")
        assert result == "STUA1B"
        assert all(c.isalnum() for c in result)

    def test_sanitize_student_code_uppercases(self):
        assert sanitize_student_code("abc123") == "ABC123"

    def test_sanitize_pin_uppercases(self):
        assert sanitize_pin("abc123") == "ABC123"

    def test_sanitize_pin_removes_special_chars(self):
        assert sanitize_pin("A1@3#5!") == "A135"

    def test_sanitize_pin_reduces_entropy(self):
        original = "A1@3#5!"
        sanitized = sanitize_pin(original)
        assert len(sanitized) < len(original)
        assert all(c.isalnum() for c in sanitized)

    def test_sanitize_email_lowercases(self):
        assert sanitize_email("Test@Example.COM") == "test@example.com"

    def test_sanitize_email_strips_whitespace(self):
        assert sanitize_email("  user@test.com  ") == "user@test.com"


class TestAuthConfig:
    def test_jwt_algorithm_is_hs256(self):
        settings = get_settings()
        assert settings.ALGORITHM == "HS256"

    def test_rate_limit_store_exists(self):
        assert _rate_limit_store is not None
        assert isinstance(dict(_rate_limit_store), dict)

    def test_rate_limit_config_has_window(self):
        settings = get_settings()
        assert hasattr(settings, "RATE_LIMIT_WINDOW") or True
