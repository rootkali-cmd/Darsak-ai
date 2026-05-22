import logging
from datetime import datetime

logger = logging.getLogger("darsak")


class ConflictResolver:
    @staticmethod
    def resolve(local_change: dict, cloud_change: dict) -> dict:
        local_ts = local_change.get("timestamp", "")
        cloud_ts = cloud_change.get("timestamp", "")

        try:
            local_dt = datetime.fromisoformat(local_ts)
            cloud_dt = datetime.fromisoformat(cloud_ts)
        except (ValueError, TypeError):
            return {**cloud_change, "resolved_by": "cloud_default"}

        if local_dt > cloud_dt:
            merged = {**cloud_change, **local_change, "resolved_by": "local_newer"}
        else:
            merged = {**local_change, **cloud_change, "resolved_by": "cloud_newer"}

        if local_dt == cloud_dt:
            merged["conflict_log"] = {
                "local": local_change.get("data"),
                "cloud": cloud_change.get("data"),
            }
            logger.warning(
                "Conflict detected at same timestamp: local=%s, cloud=%s",
                local_change.get("data"),
                cloud_change.get("data"),
            )

        return merged
