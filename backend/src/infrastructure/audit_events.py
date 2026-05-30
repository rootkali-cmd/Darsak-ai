"""Asynchronous audit logging via background tasks.

Instead of blocking the response for DB writes, audit events are published
to an in-memory queue and processed in the background.
"""
import asyncio
import logging
from typing import Any
from datetime import datetime, timezone

logger = logging.getLogger("darsak")


class AuditEvent:
    def __init__(
        self,
        actor_type: str,
        action: str,
        actor_id: str,
        resource_type: str,
        resource_id: str,
        ip_address: str = "unknown",
        metadata: dict | None = None,
    ):
        self.actor_type = actor_type
        self.action = action
        self.actor_id = actor_id
        self.resource_type = resource_type
        self.resource_id = resource_id
        self.ip_address = ip_address
        self.metadata = metadata
        self.timestamp = datetime.now(timezone.utc).isoformat()


class AuditPublisher:
    """Non-blocking audit logger.
    
    Events are queued in memory and flushed in batches to Supabase.
    If DB is unavailable, up to `max_queue` events are kept; overflow is dropped.
    """
    
    def __init__(self, max_queue: int = 1000, flush_interval: float = 2.0):
        self._queue: asyncio.Queue[AuditEvent] = asyncio.Queue(maxsize=max_queue)
        self._flush_interval = flush_interval
        self._running = False
        self._dispatched_count = 0
        self._dropped_count = 0
        self._total_repo = None  # Set during init
        self._worker_task: asyncio.Task | None = None
    
    def set_repo(self, repo):
        self._total_repo = repo
    
    async def start(self):
        if self._running:
            return
        self._running = True
        self._worker_task = asyncio.create_task(self._flush_loop())
        logger.info("Audit publisher started")
    
    async def stop(self):
        self._running = False
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass
            self._worker_task = None
        # Flush remaining
        await self._flush()
        logger.info("Audit publisher stopped: %d dispatched, %d dropped",
                     self._dispatched_count, self._dropped_count)
    
    async def publish(self, event: AuditEvent) -> None:
        """Fire-and-forget: adds to queue, never blocks the caller."""
        try:
            self._queue.put_nowait(event)
        except asyncio.QueueFull:
            self._dropped_count += 1
            logger.warning("Audit queue full, dropped event: %s/%s",
                           event.action, event.resource_type)
    
    async def _flush_loop(self):
        while self._running:
            await asyncio.sleep(self._flush_interval)
            try:
                await self._flush()
            except Exception as e:
                logger.error("Audit flush error: %s", e, exc_info=True)
    
    async def _flush(self):
        if not self._total_repo or self._queue.empty():
            return
        
        # Drain the queue
        events: list[AuditEvent] = []
        while not self._queue.empty():
            try:
                events.append(self._queue.get_nowait())
            except asyncio.QueueEmpty:
                break
        
        if not events:
            return
        
        try:
            batch = [
                {
                    "actor_type": e.actor_type,
                    "action": e.action,
                    "actor_id": e.actor_id,
                    "resource_type": e.resource_type,
                    "resource_id": e.resource_id,
                    "ip_address": e.ip_address,
                    "metadata": e.metadata,
                    "timestamp": e.timestamp,
                }
                for e in events
            ]
            await self._total_repo.repo.insert(batch)
            self._dispatched_count += len(events)
        except Exception as e:
            logger.error("Failed to flush %d audit events: %s", len(events), e)
            # Re-queue (best effort)
            for event in events:
                try:
                    self._queue.put_nowait(event)
                except asyncio.QueueFull:
                    pass  # Give up


# Global publisher
audit = AuditPublisher()
