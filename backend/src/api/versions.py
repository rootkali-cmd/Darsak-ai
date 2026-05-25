from fastapi import APIRouter, HTTPException
from datetime import datetime, timezone
import logging

logger = logging.getLogger("darsak")
router = APIRouter(prefix="/versions", tags=["Versions"])

VERSIONS: dict[str, dict] = {
    "windows": {
        "version": "1.2.0",
        "build": 40,
        "mandatory": False,
        "changelog": [
            "تحسين نظام التحديث التلقائي مع شريط التقدم",
            "إصلاح مشكلة عدم الاتصال بالإنترنت",
            "إصلاح مشكلة تعيين PIN للطلاب",
            "تحسين الأداء والاستقرار",
        ],
        "changelog_en": [
            "Improved auto-update system with progress bar",
            "Fixed offline detection issue",
            "Fixed student PIN setting issue",
            "Performance and stability improvements",
        ],
        "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup-1.2.0.exe",
        "size_mb": 14,
        "release_date": "2026-05-24",
    },
    "linux": {
        "version": "1.2.0",
        "build": 40,
        "mandatory": False,
        "changelog": [
            "تحسين نظام التحديث التلقائي",
            "إصلاح مشكلة عدم الاتصال بالإنترنت",
            "إصلاح مشكلة تعيين PIN للطلاب",
            "تحسين الأداء والاستقرار",
        ],
        "changelog_en": [
            "Improved auto-update system",
            "Fixed offline detection issue",
            "Fixed student PIN setting issue",
            "Performance and stability improvements",
        ],
        "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Linux.tar.gz",
        "size_mb": 20,
        "release_date": "2026-05-24",
    },
    "android": {
        "version": "1.1.0",
        "build": 5,
        "mandatory": False,
        "changelog": [
            "تحسين واجهة المستخدم",
            "إصلاح أخطاء",
            "تحسين الأداء",
        ],
        "changelog_en": [
            "Improved user interface",
            "Bug fixes",
            "Performance improvements",
        ],
        "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Student.apk",
        "size_mb": 72,
        "release_date": "2026-05-24",
    },
    "accounts": {
        "version": "1.0.0",
        "build": 1,
        "mandatory": False,
        "changelog": [],
        "changelog_en": [],
        "download_url": None,
        "size_mb": None,
        "release_date": "2026-05-24",
    },
}

CACHE: dict[str, tuple[dict, datetime]] = {}
CACHE_TTL_SECONDS = 300


@router.get("/")
async def get_versions():
    return VERSIONS


@router.get("/{platform}")
async def get_version(platform: str):
    now = datetime.now(timezone.utc)

    if platform in CACHE:
        cached, timestamp = CACHE[platform]
        if (now - timestamp).total_seconds() < CACHE_TTL_SECONDS:
            return cached

    entry = VERSIONS.get(platform)
    if not entry:
        raise HTTPException(status_code=404, detail=f"Unknown platform: {platform}")

    CACHE[platform] = (entry, now)
    return entry
