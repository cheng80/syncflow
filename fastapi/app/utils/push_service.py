"""
FCM 발송 유틸리티

- push_tokens 테이블의 활성 토큰 조회
- Firebase Admin SDK를 통한 멀티캐스트 발송
- 무효 토큰 자동 비활성화
"""

from __future__ import annotations

import logging
import os
import threading
from typing import Any

from app.database.connection import connect_db

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception:  # pragma: no cover - optional dependency guard
    firebase_admin = None
    credentials = None
    messaging = None

logger = logging.getLogger(__name__)

_firebase_init_lock = threading.Lock()
_firebase_app = None


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _get_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    if firebase_admin is None or credentials is None:
        logger.warning("FCM skipped: firebase-admin not installed.")
        return None

    cred_path = (os.getenv("FIREBASE_ADMIN_CREDENTIALS") or "").strip()
    if not cred_path:
        logger.info("FCM skipped: FIREBASE_ADMIN_CREDENTIALS is not set.")
        return None
    if not os.path.exists(cred_path):
        logger.warning("FCM skipped: credentials file not found (%s).", cred_path)
        return None

    with _firebase_init_lock:
        if _firebase_app is not None:
            return _firebase_app

        options: dict[str, Any] = {}
        project_id = (os.getenv("FIREBASE_PROJECT_ID") or "").strip()
        if project_id:
            options["projectId"] = project_id

        cred = credentials.Certificate(cred_path)
        _firebase_app = firebase_admin.initialize_app(cred, options or None)
        logger.info("Firebase Admin initialized for push delivery.")
        return _firebase_app


def _fetch_active_tokens(user_ids: list[int]) -> list[str]:
    if not user_ids:
        return []

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            placeholders = ", ".join(["%s"] * len(user_ids))
            cursor.execute(
                f"""
                SELECT DISTINCT token
                  FROM push_tokens
                 WHERE is_active = TRUE
                   AND user_id IN ({placeholders})
                   AND platform IN ('ios', 'android')
                """,
                tuple(user_ids),
            )
            return [str(row[0]) for row in cursor.fetchall() if row and row[0]]
    finally:
        conn.close()


def _deactivate_tokens(tokens: list[str]) -> None:
    if not tokens:
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            placeholders = ", ".join(["%s"] * len(tokens))
            cursor.execute(
                f"""
                UPDATE push_tokens
                   SET is_active = FALSE,
                       updated_at = UTC_TIMESTAMP()
                 WHERE token IN ({placeholders})
                """,
                tuple(tokens),
            )
            conn.commit()
    finally:
        conn.close()


def _normalize_data(data: dict[str, Any] | None) -> dict[str, str]:
    if not data:
        return {}
    normalized: dict[str, str] = {}
    for key, value in data.items():
        if value is None:
            continue
        normalized[str(key)] = str(value)
    return normalized


def send_push_to_users(
    *,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    user_ids 대상에게 FCM 알림 발송.
    실패해도 예외를 상위로 던지지 않고 결과 dict 반환.
    """
    unique_user_ids = sorted({int(uid) for uid in user_ids if int(uid) > 0})
    if not unique_user_ids:
        return {"ok": False, "reason": "no_recipients"}

    if not _env_bool("FCM_PUSH_ENABLED", default=False):
        return {"ok": False, "reason": "disabled"}

    app = _get_firebase_app()
    if app is None or messaging is None:
        return {"ok": False, "reason": "firebase_unavailable"}

    tokens = _fetch_active_tokens(unique_user_ids)
    if not tokens:
        return {"ok": False, "reason": "no_active_tokens"}

    dry_run = _env_bool("FCM_DRY_RUN", default=False)
    payload_data = _normalize_data(data)

    success_count = 0
    failure_count = 0
    invalid_tokens: list[str] = []

    for start in range(0, len(tokens), 500):
        batch_tokens = tokens[start : start + 500]
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=payload_data,
            tokens=batch_tokens,
        )
        response = messaging.send_each_for_multicast(
            message,
            app=app,
            dry_run=dry_run,
        )

        success_count += int(response.success_count)
        failure_count += int(response.failure_count)

        for idx, item in enumerate(response.responses):
            if item.success:
                continue
            err_code = ""
            if item.exception is not None:
                err_code = getattr(item.exception, "code", "") or str(item.exception)
            if "registration-token-not-registered" in err_code:
                invalid_tokens.append(batch_tokens[idx])

    if invalid_tokens:
        _deactivate_tokens(invalid_tokens)

    return {
        "ok": True,
        "dry_run": dry_run,
        "requested_tokens": len(tokens),
        "success_count": success_count,
        "failure_count": failure_count,
        "deactivated_tokens": len(invalid_tokens),
    }
