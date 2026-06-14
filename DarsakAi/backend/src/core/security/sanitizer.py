import re


def sanitize_text(value: str | None) -> str | None:
    if value is None:
        return None
    return value.strip()


def sanitize_student_code(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9]', '', value.strip().upper())


def sanitize_pin(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9]', '', value.strip().upper())


def sanitize_teacher_code(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9\-]', '', value.strip().upper())


def sanitize_email(value: str) -> str:
    return value.strip().lower()
