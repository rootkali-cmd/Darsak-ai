import json
import logging
import os
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger("darsak")

LOG_DIR = os.environ.get("STRUCTURED_LOG_DIR", "logs")
os.makedirs(LOG_DIR, exist_ok=True)


def _get_log_file() -> str:
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return os.path.join(LOG_DIR, f"events-{date}.jsonl")


def write_event(
    event: str,
    severity: str = "info",
    platform: str = "unknown",
    version: str = "unknown",
    data: dict[str, Any] | None = None,
) -> None:
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": event,
        "severity": severity,
        "platform": platform,
        "version": version,
    }
    if data:
        entry["data"] = data

    try:
        with open(_get_log_file(), "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as e:
        logger.warning("Failed to write structured event: %s", e)


def read_events(
    event_filter: str | None = None,
    limit: int = 100,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    log_file = os.path.join(LOG_DIR, f"events-{date}.jsonl")

    if not os.path.exists(log_file):
        return results

    try:
        with open(log_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if event_filter and entry.get("event") != event_filter:
                        continue
                    results.append(entry)
                    if len(results) >= limit:
                        break
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        logger.warning("Failed to read events: %s", e)

    return results


def count_events(event: str | None = None, since: str | None = None) -> int:
    count = 0
    log_file = _get_log_file()

    if not os.path.exists(log_file):
        return 0

    try:
        with open(log_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if event and entry.get("event") != event:
                        continue
                    if since:
                        entry_ts = entry.get("timestamp", "")
                        if entry_ts < since:
                            continue
                    count += 1
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass

    return count


def aggregate_events(
    group_by: str = "event",
    limit: int = 50,
) -> list[dict[str, Any]]:
    counts: dict[str, int] = {}
    log_file = _get_log_file()

    if not os.path.exists(log_file):
        return []

    try:
        with open(log_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    key = entry.get(group_by, "unknown")
                    counts[key] = counts.get(key, 0) + 1
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass

    sorted_items = sorted(counts.items(), key=lambda x: -x[1])
    return [{"key": k, "count": v} for k, v in sorted_items[:limit]]
