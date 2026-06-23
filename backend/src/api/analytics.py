import json
import logging
import os
import time
from datetime import datetime, timezone
from collections import defaultdict, Counter
from fastapi import APIRouter, HTTPException, Query, Depends
from pydantic import BaseModel, field_validator
from src.core.structured_logger import write_event, count_events, aggregate_events
from src.utils.dependencies import get_current_admin, get_current_teacher

router = APIRouter(prefix="/analytics", tags=["Analytics"])

ANALYTICS_LOG = "analytics.jsonl"

ALLOWED_ANALYTICS_EVENTS = {
    "app_opened", "app_closed", "crash_detected",
    "update_check", "update_available", "update_started",
    "update_downloaded", "update_installed", "update_failed",
    "installer_failed", "hash_mismatch", "screen_view",
    "button_click", "feature_used", "error_occurred",
    "login_attempt", "logout", "exam_started", "exam_submitted",
}

_analytics_rate_limit: dict[str, list[float]] = {}
ANALYTICS_RATE_LIMIT = 100
ANALYTICS_RATE_WINDOW = 3600


class AnalyticsEventInput(BaseModel):
    event: str
    properties: dict = {}
    timestamp: str | None = None

    @field_validator("event")
    @classmethod
    def validate_event_name(cls, v: str) -> str:
        if not v or not isinstance(v, str):
            raise ValueError("Event name is required")
        v = v.strip()[:100]
        if v not in ALLOWED_ANALYTICS_EVENTS:
            raise ValueError(f"Event '{v}' is not in the allowed list")
        return v

    @field_validator("properties")
    @classmethod
    def validate_properties(cls, v: dict) -> dict:
        if not isinstance(v, dict):
            raise ValueError("Properties must be a dict")
        sanitized = {}
        for k, val in list(v.items())[:20]:
            k = str(k)[:50]
            if isinstance(val, (str, int, float, bool)):
                sanitized[k] = val if isinstance(val, str) else val
            elif isinstance(val, str):
                sanitized[k] = val[:500]
        return sanitized


def _check_analytics_rate_limit(teacher_id: str) -> None:
    now = time.time()
    if teacher_id not in _analytics_rate_limit:
        _analytics_rate_limit[teacher_id] = []
    _analytics_rate_limit[teacher_id] = [
        t for t in _analytics_rate_limit[teacher_id] if now - t < ANALYTICS_RATE_WINDOW
    ]
    if len(_analytics_rate_limit[teacher_id]) >= ANALYTICS_RATE_LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Analytics rate limit exceeded. Max 100 events per hour.",
        )
    _analytics_rate_limit[teacher_id].append(now)


@router.post("/event")
async def analytics_event(
    data: AnalyticsEventInput,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = current_user.get("id", "unknown")
        _check_analytics_rate_limit(teacher_id)

        properties = data.properties
        timestamp = data.timestamp or datetime.now(timezone.utc).isoformat()

        entry = {
            "timestamp": timestamp,
            "event": data.event,
            "severity": "info",
            "platform": properties.get("platform", "unknown"),
            "version": properties.get("version", "unknown"),
            "teacher_id": teacher_id,
            "data": {k: v for k, v in properties.items() if k not in ("platform", "version")},
        }

        with open(ANALYTICS_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

        write_event(data.event, severity="info", platform=entry["platform"], version=entry["version"], data=entry["data"])

        return {"status": "ok"}
    except HTTPException:
        raise
    except Exception:
        return {"status": "error", "detail": "Internal error"}


@router.get("/overview")
async def analytics_overview(admin: dict = Depends(get_current_admin)):
    total = count_events()
    updates = count_events("update_check")
    failures = count_events("update_failed") + count_events("installer_failed") + count_events("hash_mismatch")
    sessions = count_events("app_opened")
    crashes = count_events("crash_detected")

    update_success_rate = 0
    if updates > 0:
        update_installed = count_events("update_installed")
        update_success_rate = round((update_installed / updates) * 100)

    crash_rate = 0
    if sessions > 0:
        crash_rate = round((crashes / sessions) * 100, 1)

    return {
        "active_users": count_events("app_opened"),
        "total_sessions": sessions,
        "update_success_rate": update_success_rate,
        "crash_rate": crash_rate,
        "failed_installs": failures,
        "total_events": total,
    }


@router.get("/updates")
async def analytics_updates(admin: dict = Depends(get_current_admin)):
    checks = count_events("update_check")
    available = count_events("update_available")
    started = count_events("update_started")
    downloaded = count_events("update_downloaded")
    installed = count_events("update_installed")
    failed = count_events("update_failed") + count_events("installer_failed") + count_events("hash_mismatch")

    return {
        "checks": checks,
        "available": available,
        "started": started,
        "downloaded": downloaded,
        "installed": installed,
        "failed": failed,
        "success_rate": round((installed / max(checks, 1)) * 100),
    }


@router.get("/crashes")
async def analytics_crashes(admin: dict = Depends(get_current_admin)):
    crashes = count_events("crash_detected")
    return {
        "total_crashes": crashes,
        "crash_rate_per_session": round((crashes / max(count_events("app_opened"), 1)) * 100, 2),
    }


@router.get("/platforms")
async def analytics_platforms(admin: dict = Depends(get_current_admin)):
    events_by_platform = aggregate_events(group_by="platform")
    return {
        "platforms": events_by_platform,
        "windows": count_events("app_opened", since=None),  # simplified
    }


@router.get("/events")
async def analytics_events(
    admin: dict = Depends(get_current_admin),
    event: str | None = Query(None),
    limit: int = Query(50, le=500),
):
    results: list[dict] = []
    if not os.path.exists(ANALYTICS_LOG):
        return {"events": []}

    try:
        with open(ANALYTICS_LOG) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if event and entry.get("event") != event:
                        continue
                    results.append(entry)
                    if len(results) >= limit:
                        break
                except json.JSONDecodeError:
                    continue
    except Exception:
        logger = logging.getLogger("darsak")
        logger.debug("Failed to read analytics events")

    return {"events": results}


@router.get("/versions-usage")
async def analytics_version_usage(admin: dict = Depends(get_current_admin)):
    versions = aggregate_events(group_by="version", limit=20)
    return {"versions": versions}


@router.get("/channels")
async def analytics_channels(admin: dict = Depends(get_current_admin)):
    data_entries: list[dict] = []
    if not os.path.exists(ANALYTICS_LOG):
        return {"channels": []}

    try:
        with open(ANALYTICS_LOG) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    channel = entry.get("data", {}).get("channel", "unknown")
                    data_entries.append({"channel": channel, "event": entry.get("event")})
                except json.JSONDecodeError:
                    continue
    except Exception:
        logging.getLogger("darsak").debug("Failed to read analytics channels")

    channel_counts: dict[str, int] = {}
    for de in data_entries:
        ch = de["channel"]
        channel_counts[ch] = channel_counts.get(ch, 0) + 1

    return {
        "channels": [{"key": k, "count": v} for k, v in sorted(channel_counts.items(), key=lambda x: -x[1])]
    }
