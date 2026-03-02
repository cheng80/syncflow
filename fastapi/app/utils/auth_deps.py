"""
세션 토큰 기반 인증 의존성
X-Session-Token 헤더에서 user_id 추출
"""

from fastapi import Header, HTTPException

from app.database.connection import connect_db


def get_user_id_from_token(session_token: str) -> int:
    """세션 토큰으로 user_id 조회"""
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id FROM sessions
                WHERE session_token = %s
                  AND expires_at > UTC_TIMESTAMP()
                  AND revoked = FALSE
                """,
                (session_token,),
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=401, detail="세션이 유효하지 않습니다.")
            return row[0]
    finally:
        conn.close()


async def get_current_user_id(
    x_session_token: str | None = Header(None, alias="X-Session-Token"),
) -> int:
    """인증 필요 API에서 사용. user_id 반환"""
    if not x_session_token or not x_session_token.strip():
        raise HTTPException(status_code=401, detail="세션 토큰이 필요합니다.")
    return get_user_id_from_token(x_session_token.strip())
