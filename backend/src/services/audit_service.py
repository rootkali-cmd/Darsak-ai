import logging
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.audit_log import AuditLog, ActorType

logger = logging.getLogger("darsak")


async def log_audit(
    db: AsyncSession,
    actor_type: ActorType,
    action: str,
    actor_id: UUID | None = None,
    resource_type: str | None = None,
    resource_id: UUID | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    metadata: dict | None = None,
):
    entry = AuditLog(
        actor_type=actor_type,
        actor_id=actor_id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        ip_address=ip_address,
        user_agent=user_agent,
        extra_metadata=metadata,
    )
    db.add(entry)
    logger.debug("Audit log: %s by %s on %s", action, actor_type, resource_type)
