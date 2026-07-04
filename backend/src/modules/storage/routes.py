from fastapi import APIRouter
from src.core.security.supabase_repo import SupabaseRepository

router = APIRouter()

_course_files_repo = SupabaseRepository("course_files")


async def _check_storage_quota(teacher_id: str, size_bytes: int):
    pass


async def _compute_storage_usage(teacher_id: str) -> dict:
    return {"used_bytes": 0, "quota_bytes": 0, "files": 0}
