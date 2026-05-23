import re
import html


def sanitize_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = html.escape(value, quote=True)
    value = re.sub(r'[<>\'";()\[\]{}]', '', value)
    value = re.sub(r'\b(select|insert|update|delete|drop|alter|create|exec|union|eval|script|javascript|onclick|onerror|onload)\b', '', value, flags=re.IGNORECASE)
    return value.strip()


def sanitize_student_code(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9]', '', value.strip().upper())


def sanitize_pin(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9]', '', value.strip().upper())


def sanitize_teacher_code(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9\-]', '', value.strip().upper())


def sanitize_email(value: str) -> str:
    return value.strip().lower()
