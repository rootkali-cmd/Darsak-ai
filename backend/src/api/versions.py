from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse
from datetime import datetime, timezone
import logging
import json
import os

logger = logging.getLogger("darsak")
router = APIRouter(prefix="", tags=["Versions"])

CHANNELS: dict[str, dict[str, dict]] = {
    "stable": {
        "windows": {
            "version": "1.2.0",
            "build": 61,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 100,
            "sha256": None,
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
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup.exe",
            "size_mb": 14,
            "release_date": "2026-05-25",
        },
        "linux": {
            "version": "1.2.0",
            "build": 61,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 100,
            "sha256": None,
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
            "release_date": "2026-05-25",
        },
        "android": {
            "version": "1.1.0",
            "build": 5,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 100,
            "sha256": None,
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
            "release_date": "2026-05-25",
        },
        "accounts": {
            "version": "1.0.0",
            "build": 1,
            "mandatory": False,
            "min_supported_version": None,
            "rollout": 100,
            "sha256": None,
            "changelog": [],
            "changelog_en": [],
            "download_url": None,
            "size_mb": None,
            "release_date": "2026-05-25",
        },
    },
    "beta": {
        "windows": {
            "version": "1.3.0-beta.1",
            "build": 70,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 25,
            "sha256": None,
            "changelog": [
                "اختبار تجريبي v1.3.0",
                "تحسينات الأمان",
                "إصلاح أخطاء",
            ],
            "changelog_en": [
                "Beta test v1.3.0",
                "Security improvements",
                "Bug fixes",
            ],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup.exe",
            "size_mb": 14,
            "release_date": "2026-05-25",
        },
        "linux": {
            "version": "1.3.0-beta.1",
            "build": 70,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 25,
            "sha256": None,
            "changelog": [
                "اختبار تجريبي v1.3.0",
                "تحسينات الأمان",
            ],
            "changelog_en": [
                "Beta test v1.3.0",
                "Security improvements",
            ],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Linux.tar.gz",
            "size_mb": 20,
            "release_date": "2026-05-25",
        },
        "android": {
            "version": "1.2.0-beta.1",
            "build": 6,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 25,
            "sha256": None,
            "changelog": [
                "اختبار تجريبي",
                "واجهة محسنة",
            ],
            "changelog_en": [
                "Beta test",
                "Improved interface",
            ],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Student.apk",
            "size_mb": 72,
            "release_date": "2026-05-25",
        },
        "accounts": {
            "version": "1.0.0",
            "build": 1,
            "mandatory": False,
            "min_supported_version": None,
            "rollout": 100,
            "sha256": None,
            "changelog": [],
            "changelog_en": [],
            "download_url": None,
            "size_mb": None,
            "release_date": "2026-05-25",
        },
    },
    "dev": {
        "windows": {
            "version": "1.4.0-dev",
            "build": 80,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 10,
            "sha256": None,
            "changelog": ["تطوير مستمر"],
            "changelog_en": ["Continuous development"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup.exe",
            "size_mb": 14,
            "release_date": "2026-05-25",
        },
        "linux": {
            "version": "1.4.0-dev",
            "build": 80,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 10,
            "sha256": None,
            "changelog": ["تطوير مستمر"],
            "changelog_en": ["Continuous development"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Linux.tar.gz",
            "size_mb": 20,
            "release_date": "2026-05-25",
        },
        "android": {
            "version": "1.3.0-dev",
            "build": 7,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 10,
            "sha256": None,
            "changelog": ["تطوير مستمر"],
            "changelog_en": ["Continuous development"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Student.apk",
            "size_mb": 72,
            "release_date": "2026-05-25",
        },
        "accounts": {
            "version": "1.0.0",
            "build": 1,
            "mandatory": False,
            "min_supported_version": None,
            "rollout": 100,
            "sha256": None,
            "changelog": [],
            "changelog_en": [],
            "download_url": None,
            "size_mb": None,
            "release_date": "2026-05-25",
        },
    },
    "nightly": {
        "windows": {
            "version": "1.5.0-nightly",
            "build": 90,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 5,
            "sha256": None,
            "changelog": ["إصدار ليلي"],
            "changelog_en": ["Nightly build"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup.exe",
            "size_mb": 14,
            "release_date": "2026-05-25",
        },
        "linux": {
            "version": "1.5.0-nightly",
            "build": 90,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 5,
            "sha256": None,
            "changelog": ["إصدار ليلي"],
            "changelog_en": ["Nightly build"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Linux.tar.gz",
            "size_mb": 20,
            "release_date": "2026-05-25",
        },
        "android": {
            "version": "1.4.0-nightly",
            "build": 8,
            "mandatory": False,
            "min_supported_version": "1.0.0",
            "rollout": 5,
            "sha256": None,
            "changelog": ["إصدار ليلي"],
            "changelog_en": ["Nightly build"],
            "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Student.apk",
            "size_mb": 72,
            "release_date": "2026-05-25",
        },
        "accounts": {
            "version": "1.0.0",
            "build": 1,
            "mandatory": False,
            "min_supported_version": None,
            "rollout": 100,
            "sha256": None,
            "changelog": [],
            "changelog_en": [],
            "download_url": None,
            "size_mb": None,
            "release_date": "2026-05-25",
        },
    },
}

CACHE: dict[str, tuple[dict, datetime]] = {}
CACHE_TTL_SECONDS = 300


@router.get("/versions/")
async def get_versions():
    return CHANNELS


@router.get("/versions/{platform}")
async def get_version(
    platform: str,
    channel: str = Query("stable", description="Release channel"),
):
    now = datetime.now(timezone.utc)

    cache_key = f"{platform}:{channel}"
    if cache_key in CACHE:
        cached, timestamp = CACHE[cache_key]
        if (now - timestamp).total_seconds() < CACHE_TTL_SECONDS:
            return cached

    channel_data = CHANNELS.get(channel)
    if not channel_data:
        raise HTTPException(status_code=404, detail=f"Unknown channel: {channel}")

    entry = channel_data.get(platform)
    if not entry:
        raise HTTPException(status_code=404, detail=f"Unknown platform: {platform}")

    result = {**entry, "channel": channel}
    CACHE[cache_key] = (result, now)
    return result


@router.get("/download/{platform}/latest")
async def download_latest(
    platform: str,
    channel: str = Query("stable", description="Release channel"),
):
    channel_data = CHANNELS.get(channel)
    if not channel_data:
        raise HTTPException(status_code=404, detail=f"Unknown channel: {channel}")

    entry = channel_data.get(platform)
    if not entry or not entry.get("download_url"):
        raise HTTPException(status_code=404, detail=f"No download available for {platform} on {channel}")

    logger.info(f"Redirecting download for {platform}/{channel} -> {entry['download_url']}")
    return RedirectResponse(url=entry["download_url"], status_code=302)


TELEMETRY_LOG = "telemetry.jsonl"


@router.post("/telemetry/event")
async def telemetry_event(data: dict):
    try:
        entry = {
            "event": data.get("event"),
            "version": data.get("version"),
            "platform": data.get("platform"),
            "timestamp": data.get("timestamp", datetime.now(timezone.utc).isoformat()),
            "error": data.get("error"),
        }
        with open(TELEMETRY_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
        return {"status": "ok"}
    except Exception as e:
        logger.warning(f"Telemetry write failed: {e}")
        return {"status": "error", "detail": str(e)}
