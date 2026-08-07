"""FCM push notifications (TRK-3): data-only pushes to a user's `fcm_token`.

Wraps `firebase_admin.messaging` on top of the same lazily-initialized Firebase
Admin app `app/core/security.py` already sets up for auth-token verification --
`messaging.send()` reuses that default app, so there's no separate credentials
or setup path here.

Sending is always best-effort: a falsy token, Firebase not being configured yet
(mirrors security.py's "no FIREBASE_CREDENTIALS_PATH" as a valid state, not an
error), or any SDK/network failure all just log and return -- this is called
from inside the job-transition/dispatch flow (app/services/realtime.py) and
must never be able to break it.
"""

import asyncio
import logging

from app.core.security import _init_firebase

logger = logging.getLogger(__name__)


async def send_push(token: str, data: dict[str, str]) -> None:
    """Send a data-only FCM message (no `notification` block) to `token`.

    `data` mirrors the existing WS message shape -- at minimum `type`/`job_id`
    -- so a future Flutter FCM handler can dispatch on the same `type` field it
    already reads from `ServerMessage.fromWire` (lib/core/ws/server_message.dart).
    """
    if not token:
        return
    try:
        _init_firebase()
    except Exception:
        logger.info("FCM push skipped: Firebase Admin is not configured")
        return

    from firebase_admin import messaging

    message = messaging.Message(data=data, token=token)
    try:
        # messaging.send() is a blocking network call -- run it off the event
        # loop so a slow/unreachable FCM never stalls the WS/dispatch flow.
        await asyncio.to_thread(messaging.send, message)
    except Exception:
        logger.warning("FCM push to token failed", exc_info=True)
