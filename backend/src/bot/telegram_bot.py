"""Telegram bot stubs — all bot logic is now in src/api/webhook.py"""
import logging

logger = logging.getLogger("darsak")


async def start_bot():
    """Bot startup — webhook is set via /setup-telegram-webhook endpoint."""
    logger.info("Telegram bot uses webhook mode. Use POST /api/setup-telegram-webhook to configure.")


async def stop_bot():
    """Bot shutdown — no-op for webhook mode."""
    pass
