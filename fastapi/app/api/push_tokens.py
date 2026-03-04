"""
FCM push token 등록/비활성화 API
"""

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.database.connection import connect_db
from app.utils.auth_deps import get_current_user_id

router = APIRouter()


def _ensure_push_tokens_table(cursor) -> None:
    """push_tokens 테이블이 없으면 생성."""
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS push_tokens (
          id BIGINT AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT NOT NULL,
          platform VARCHAR(16) NOT NULL,
          token VARCHAR(512) NOT NULL,
          device_id VARCHAR(128) DEFAULT NULL,
          app_version VARCHAR(32) DEFAULT NULL,
          is_active BOOLEAN NOT NULL DEFAULT TRUE,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          UNIQUE KEY uk_platform_token (platform, token),
          INDEX idx_user_active (user_id, is_active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
    )


class PushTokenUpsertRequest(BaseModel):
    token: str
    platform: Literal["ios", "android", "web"]
    device_id: str | None = None
    app_version: str | None = None


@router.post("/push-tokens")
async def upsert_push_token(
    req: PushTokenUpsertRequest,
    user_id: int = Depends(get_current_user_id),
):
    token = req.token.strip()
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            _ensure_push_tokens_table(cursor)
            cursor.execute(
                """
                INSERT INTO push_tokens (user_id, platform, token, device_id, app_version, is_active)
                VALUES (%s, %s, %s, %s, %s, TRUE)
                ON DUPLICATE KEY UPDATE
                  user_id = VALUES(user_id),
                  device_id = VALUES(device_id),
                  app_version = VALUES(app_version),
                  is_active = TRUE,
                  updated_at = UTC_TIMESTAMP()
                """,
                (user_id, req.platform, token, req.device_id, req.app_version),
            )
            conn.commit()
        return {"ok": True}
    finally:
        conn.close()


@router.delete("/push-tokens/{token}")
async def deactivate_push_token(
    token: str,
    user_id: int = Depends(get_current_user_id),
):
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            _ensure_push_tokens_table(cursor)
            cursor.execute(
                """
                UPDATE push_tokens
                   SET is_active = FALSE,
                       updated_at = UTC_TIMESTAMP()
                 WHERE user_id = %s
                   AND token = %s
                """,
                (user_id, token.strip()),
            )
            conn.commit()
        return {"ok": True}
    finally:
        conn.close()
