import os
import json
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Firebase Admin SDK - initialized lazily
_firebase_initialized = False
_firebase_app = None


def _initialize_firebase():
    """Initialize Firebase Admin SDK using service account credentials from env."""
    global _firebase_initialized, _firebase_app
    if _firebase_initialized:
        return True

    try:
        import firebase_admin
        from firebase_admin import credentials

        # Try to get credentials from environment variable (JSON string)
        service_account_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "")

        if service_account_json:
            # Parse JSON string from env
            service_account_info = json.loads(service_account_json)
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully (from env)")
            return True

        # Try to get from file path
        service_account_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "")
        if service_account_path and os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully (from file)")
            return True

        # Try default credentials
        try:
            firebase_admin.initialize_app()
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully (default credentials)")
            return True
        except Exception:
            pass

        logger.warning("Firebase Admin SDK: No credentials found. Push notifications will be disabled.")
        return False

    except ImportError:
        logger.warning("firebase-admin not installed. Push notifications disabled.")
        return False
    except Exception as e:
        logger.error(f"Firebase Admin SDK initialization failed: {e}")
        return False


async def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    notification_id: Optional[str] = None,
) -> bool:
    """Send a push notification via FCM to a single device."""
    if not _initialize_firebase():
        return False

    try:
        from firebase_admin import messaging

        notification = messaging.Notification(
            title=title,
            body=body,
        )

        android_config = messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="darsak_push_channel",
                sound="default",
            ),
            data=data or {},
        )

        message = messaging.Message(
            notification=notification,
            android=android_config,
            token=fcm_token,
            data={
                **(data or {}),
                "notification_id": notification_id or "",
                "title": title,
                "body": body,
            },
        )

        response = messaging.send(message)
        logger.info(f"Push notification sent successfully: {response}")
        return True

    except messaging.UnregisteredError:
        logger.warning(f"FCM token expired/unregistered: {fcm_token[:20]}...")
        return False
    except messaging.SenderIdMismatchError:
        logger.warning(f"FCM token belongs to different sender: {fcm_token[:20]}...")
        return False
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        return False


async def send_push_to_user(
    user_id: str,
    user_type: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    notification_id: Optional[str] = None,
) -> int:
    """Send push notification to all devices of a user. Returns count of successful sends."""
    if not _initialize_firebase():
        return 0

    try:
        from src.core.security.supabase_repo import get_supabase
        settings = __import__('src.core.config', fromlist=['get_settings']).get_settings()

        client = await get_supabase()
        url = settings.SUPABASE_URL.rstrip("/")
        key = settings.SUPABASE_SERVICE_ROLE_KEY

        import httpx
        async with httpx.AsyncClient() as http:
            resp = await http.get(
                f"{url}/rest/v1/fcm_tokens",
                params={
                    "select": "fcm_token",
                    "user_id": f"eq.{user_id}",
                    "user_type": f"eq.{user_type}",
                    "is_active": "eq.true",
                },
                headers={
                    "apikey": key,
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
            )

            if resp.status_code != 200:
                logger.error(f"Failed to fetch FCM tokens: {resp.status_code}")
                return 0

            tokens = resp.json()
            if not tokens:
                return 0

            success_count = 0
            stale_tokens = []

            for token_record in tokens:
                token = token_record.get("fcm_token")
                if not token:
                    continue

                success = await send_push_notification(
                    fcm_token=token,
                    title=title,
                    body=body,
                    data=data,
                    notification_id=notification_id,
                )
                if success:
                    success_count += 1
                else:
                    stale_tokens.append(token)

            # Clean up stale tokens
            if stale_tokens:
                for stale_token in stale_tokens:
                    await http.delete(
                        f"{url}/rest/v1/fcm_tokens",
                        params={
                            "user_id": f"eq.{user_id}",
                            "fcm_token": f"eq.{stale_token}",
                        },
                        headers={
                            "apikey": key,
                            "Authorization": f"Bearer {key}",
                        },
                    )

            return success_count

    except Exception as e:
        logger.error(f"Failed to send push to user {user_id}: {e}")
        return 0
