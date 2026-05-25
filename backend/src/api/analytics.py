import json
import os
from datetime import datetime, timezone
from collections import defaultdict, Counter
from fastapi import APIRouter, HTTPException, Query
from src.core.structured_logger import write_event, count_events, aggregate_events

router = APIRouter(prefix="/analytics", tags=["Analytics"])

ANALYTICS_LOG = "analytics.jsonl"


@router.post("/event")
async def analytics_event(data: dict):
    try:
        event = data.get("event", "unknown")
        properties = data.get("properties", {})
        timestamp = data.get("timestamp", datetime.now(timezone.utc).isoformat())

        entry = {
            "timestamp": timestamp,
            "event": event,
            "severity": "info",
            "platform": properties.get("platform", "unknown"),
            "version": properties.get("version", "unknown"),
            "data": {k: v for k, v in properties.items() if k not in ("platform", "version")},
        }

        with open(ANALYTICS_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

        write_event(event, severity="info", platform=entry["platform"], version=entry["version"], data=entry["data"])

        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "detail": str(e)}


@router.get("/overview")
async def analytics_overview():
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
async def analytics_updates():
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
async def analytics_crashes():
    crashes = count_events("crash_detected")
    return {
        "total_crashes": crashes,
        "crash_rate_per_session": round((crashes / max(count_events("app_opened"), 1)) * 100, 2),
    }


@router.get("/platforms")
async def analytics_platforms():
    events_by_platform = aggregate_events(group_by="platform")
    return {
        "platforms": events_by_platform,
        "windows": count_events("app_opened", since=None),  # simplified
    }


@router.get("/events")
async def analytics_events(
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
        pass

    return {"events": results}


@router.get("/versions-usage")
async def analytics_version_usage():
    versions = aggregate_events(group_by="version", limit=20)
    return {"versions": versions}


@router.get("/channels")
async def analytics_channels():
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
        pass

    channel_counts: dict[str, int] = {}
    for de in data_entries:
        ch = de["channel"]
        channel_counts[ch] = channel_counts.get(ch, 0) + 1

    return {
        "channels": [{"key": k, "count": v} for k, v in sorted(channel_counts.items(), key=lambda x: -x[1])]
    }
