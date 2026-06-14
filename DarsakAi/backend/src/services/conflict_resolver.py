import logging
from datetime import datetime
from typing import Any

logger = logging.getLogger("darsak")


class ConflictResolver:
    SERVER_AUTHORITATIVE_TABLES = {"invoices", "attendances"}
    FIELD_BASED_MERGE_TABLES = {"students", "groups"}

    @staticmethod
    def resolve(local_change: dict, cloud_change: dict, table: str = "") -> dict:
        local_ts = local_change.get("timestamp", "")
        cloud_ts = cloud_change.get("timestamp", "")

        try:
            local_dt = datetime.fromisoformat(local_ts)
            cloud_dt = datetime.fromisoformat(cloud_ts)
        except (ValueError, TypeError):
            return {**cloud_change, "resolved_by": "cloud_default"}

        if table in ConflictResolver.SERVER_AUTHORITATIVE_TABLES:
            merged = {**local_change, **cloud_change, "resolved_by": "server_authoritative"}
            if local_dt == cloud_dt:
                merged["conflict_log"] = {
                    "local": local_change.get("data"),
                    "cloud": cloud_change.get("data"),
                    "resolver": "server_authoritative",
                }
            return merged

        if table in ConflictResolver.FIELD_BASED_MERGE_TABLES:
            merged = ConflictResolver._field_merge(local_change, cloud_change, local_dt, cloud_dt)
            if merged.get("conflict_log"):
                logger.warning(
                    "Field-level conflict in %s: local=%s, cloud=%s",
                    table,
                    local_change.get("data"),
                    cloud_change.get("data"),
                )
            return merged

        if local_dt > cloud_dt:
            merged = {**cloud_change, **local_change, "resolved_by": "local_newer"}
        else:
            merged = {**local_change, **cloud_change, "resolved_by": "cloud_newer"}

        if local_dt == cloud_dt:
            merged["conflict_log"] = {
                "local": local_change.get("data"),
                "cloud": cloud_change.get("data"),
                "resolver": "last_writer_wins",
            }
            logger.warning(
                "Conflict detected at same timestamp: local=%s, cloud=%s",
                local_change.get("data"),
                cloud_change.get("data"),
            )

        return merged

    @staticmethod
    def _field_merge(local: dict, cloud: dict, local_dt: datetime, cloud_dt: datetime) -> dict:
        local_data = local.get("data", {}) or {}
        cloud_data = cloud.get("data", {}) or {}

        merged_data = {}
        conflict_fields = []

        all_keys = set(local_data.keys()) | set(cloud_data.keys())

        for key in all_keys:
            local_val = local_data.get(key)
            cloud_val = cloud_data.get(key)

            if local_val is None and cloud_val is None:
                continue
            if local_val is None:
                merged_data[key] = cloud_val
                continue
            if cloud_val is None:
                merged_data[key] = local_val
                continue
            if local_val == cloud_val:
                merged_data[key] = local_val
                continue

            immutable_fields = {"id", "code", "created_at", "teacher_id"}
            if key in immutable_fields:
                merged_data[key] = cloud_val
                continue

            if local_dt > cloud_dt:
                merged_data[key] = local_val
            elif cloud_dt > local_dt:
                merged_data[key] = cloud_val
            else:
                merged_data[key] = cloud_val

            conflict_fields.append({
                "field": key,
                "local": local_val,
                "cloud": cloud_val,
                "resolved_to": merged_data[key],
            })

        result = {**cloud, **local, "data": merged_data}
        if conflict_fields:
            result["conflict_log"] = {
                "fields": conflict_fields,
                "resolver": "field_level_merge",
            }
        result["resolved_by"] = "field_level_merge" if conflict_fields else "no_conflict"

        return result

    @staticmethod
    def resolve_batch(changes: list[dict], server_state: dict, table: str) -> list[dict]:
        resolved = []
        for change in changes:
            resolved.append(ConflictResolver.resolve(change, server_state, table))
        return resolved
