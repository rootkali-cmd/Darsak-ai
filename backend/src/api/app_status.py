import logging
from fastapi import APIRouter

from src.core.security.supabase_repo import SupabaseRepository

logger = logging.getLogger("darsak")

router = APIRouter(tags=["App Status"])

_config_repo = SupabaseRepository("admin_config")

LATEST_VERSION_STUDENT = "1.8.0"
LATEST_VERSION_TEACHER = "2.5.3"
UPDATE_URL_STUDENT = "https://github.com/rootkali-cmd/Darsak-ai/releases/download/student-v1.8.0/student-v1.8.0-universal.apk"
UPDATE_URL_TEACHER = "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/app-release.apk"


def _get_release_notes(platform: str) -> list[str]:
    try:
        from src.api.versions import CHANNELS
        entry = CHANNELS.get("stable", {}).get(platform, {})
        return entry.get("changelog", [])
    except Exception:
        return []


@router.get("/app-status")
async def get_app_status():
    maintenance_student = False
    maintenance_teacher = False
    message = ""

    try:
        row = await _config_repo.select_one({"key": "maintenance_student"})
        if row and row.get("value", "").strip().lower() == "true":
            maintenance_student = True
    except Exception as exc:
        logger.warning("Failed to read maintenance_student config: %s", exc)

    try:
        row = await _config_repo.select_one({"key": "maintenance_teacher"})
        if row and row.get("value", "").strip().lower() == "true":
            maintenance_teacher = True
    except Exception as exc:
        logger.warning("Failed to read maintenance_teacher config: %s", exc)

    try:
        row = await _config_repo.select_one({"key": "maintenance_message"})
        if row:
            message = row.get("value", "") or ""
    except Exception:
        pass

    under_maintenance = maintenance_student or maintenance_teacher

    return {
        "under_maintenance": under_maintenance,
        "maintenance_student": maintenance_student,
        "maintenance_teacher": maintenance_teacher,
        "message": message,
        "latest_version_student": LATEST_VERSION_STUDENT,
        "latest_version_teacher": LATEST_VERSION_TEACHER,
        "update_url_student": UPDATE_URL_STUDENT,
        "update_url_teacher": UPDATE_URL_TEACHER,
        "release_notes_student": _get_release_notes("android_student"),
        "release_notes_teacher": _get_release_notes("android"),
    }
