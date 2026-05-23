from fastapi import APIRouter, Request, HTTPException
from src.bot.telegram_bot import get_bot_app, start_bot

router = APIRouter()


def _ensure_bot():
    app = get_bot_app()
    if app is not None:
        return app
    import asyncio
    try:
        asyncio.create_task(start_bot())
    except Exception:
        pass
    return get_bot_app()


@router.post("/telegram-webhook")
async def telegram_webhook(request: Request):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    app = _ensure_bot()
    if app is None:
        raise HTTPException(status_code=500, detail="Bot not initialized")

    try:
        from telegram import Update
        update = Update.de_json(body, app.bot)
        await app.process_update(update)
    except Exception as e:
        from src.core.logging import setup_logging
        logger = setup_logging("INFO")
        logger.error("Failed to process Telegram update: %s", e)

    return {"ok": True}


@router.post("/setup-telegram-webhook")
async def setup_telegram_webhook():
    app = _ensure_bot()
    if app is None:
        raise HTTPException(status_code=500, detail="Bot not initialized")
    from src.core.logging import setup_logging
    logger = setup_logging("INFO")
    from src.core.config import get_settings
    settings = get_settings()
    import os
    vercel_url = os.environ.get("VERCEL_URL", "")
    if vercel_url:
        webhook_url = f"https://{vercel_url}/api/telegram-webhook"
        await app.bot.set_webhook(url=webhook_url)
        logger.info("Telegram webhook manually set to %s", webhook_url)
        return {"ok": True, "webhook_url": webhook_url}
    return {"ok": False, "detail": "VERCEL_URL not set"}

