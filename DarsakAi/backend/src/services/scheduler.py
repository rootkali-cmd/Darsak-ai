import logging
import pytz
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger("darsak")

scheduler = AsyncIOScheduler(timezone=pytz.timezone("Africa/Cairo"))


async def daily_sync_trigger():
    logger.info("Daily sync trigger at 6:00 PM Cairo time")


def start_scheduler():
    scheduler.add_job(
        daily_sync_trigger,
        trigger="cron",
        hour=18,
        minute=0,
        id="daily_sync_broadcast",
        replace_existing=True,
    )
    if not scheduler.running:
        scheduler.start()
        logger.info("Scheduler started")


def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        logger.info("Scheduler stopped")
