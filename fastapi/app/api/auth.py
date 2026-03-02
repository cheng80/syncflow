"""
SyncFlow 인증 API
이메일 6자리 코드 인증 → UUID4 세션 토큰 (14일)
"""

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.database.connection import connect_db
from app.utils.auth_deps import get_current_user_id
from app.utils.email_service import EmailService

router = APIRouter()


@router.get("/me")
async def get_me(user_id: int = Depends(get_current_user_id)):
    """현재 로그인 사용자 정보 (X-Session-Token 필요)"""
    return {"user_id": user_id}


CODE_EXPIRES_MINUTES = 10
MAX_ATTEMPTS = 5
SESSION_EXPIRES_DAYS = 14


def _generate_code() -> str:
    """6자리 숫자 코드 생성"""
    return "".join(secrets.choice("0123456789") for _ in range(6))


def _hash_code(code: str) -> str:
    """SHA256 해시"""
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


class SendCodeRequest(BaseModel):
    email: str


class VerifyRequest(BaseModel):
    email: str
    code: str


@router.post("/send-code")
async def send_code(req: SendCodeRequest):
    """
    이메일로 6자리 인증 코드 발송
    - email_verifications에 code_hash 저장
    - 이메일 발송
    """
    email = req.email.lower().strip()
    code = _generate_code()
    code_hash = _hash_code(code)
    expires_at = datetime.utcnow() + timedelta(minutes=CODE_EXPIRES_MINUTES)

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            # 새 인증 코드 저장 (동일 이메일 여러 건 허용, 검증 시 최신 사용)
            cursor.execute(
                """
                INSERT INTO email_verifications (email, code_hash, expires_at, attempt_count)
                VALUES (%s, %s, %s, 0)
                """,
                (email, code_hash, expires_at)
            )
            conn.commit()

        if EmailService.send_login_code(email, code, CODE_EXPIRES_MINUTES):
            return {"ok": True, "message": "인증 코드가 발송되었습니다."}
        raise HTTPException(status_code=500, detail="이메일 발송 실패")
    finally:
        conn.close()


@router.post("/verify")
async def verify(req: VerifyRequest):
    """
    인증 코드 검증 → users 생성/조회 → sessions 생성 → session_token 반환
    """
    email = req.email.lower().strip()
    code = req.code.strip()

    if len(code) != 6 or not code.isdigit():
        raise HTTPException(status_code=400, detail="인증 코드는 6자리 숫자여야 합니다.")

    code_hash = _hash_code(code)
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            # email_verifications 검증
            cursor.execute(
                """
                SELECT id, attempt_count FROM email_verifications
                WHERE email = %s AND code_hash = %s AND expires_at > UTC_TIMESTAMP()
                """,
                (email, code_hash)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=400, detail="인증 코드가 올바르지 않거나 만료되었습니다.")

            ev_id, attempt_count = row
            if attempt_count >= MAX_ATTEMPTS:
                raise HTTPException(status_code=400, detail="시도 횟수 초과. 새 코드를 요청하세요.")

            # users에 없으면 생성
            cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
            user_row = cursor.fetchone()
            if user_row:
                user_id = user_row[0]
            else:
                cursor.execute(
                    "INSERT INTO users (email, email_verified_at) VALUES (%s, UTC_TIMESTAMP())",
                    (email,)
                )
                user_id = cursor.lastrowid

            # 세션 생성 (UUID4, 14일)
            session_token = str(uuid.uuid4())
            expires_at = datetime.utcnow() + timedelta(days=SESSION_EXPIRES_DAYS)

            cursor.execute(
                """
                INSERT INTO sessions (user_id, session_token, expires_at)
                VALUES (%s, %s, %s)
                """,
                (user_id, session_token, expires_at)
            )
            conn.commit()

            # 사용한 인증 코드 무효화 (attempt_count로 표시하거나 삭제)
            cursor.execute("DELETE FROM email_verifications WHERE id = %s", (ev_id,))
            conn.commit()

        return {
            "session_token": session_token,
            "expires_at": expires_at.isoformat() + "Z",
            "user_id": user_id,
        }
    finally:
        conn.close()


class LogoutRequest(BaseModel):
    session_token: str


@router.post("/logout")
async def logout(req: LogoutRequest):
    """
    세션 폐기 (revoked = true)
    """
    session_token = req.session_token
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE sessions SET revoked = TRUE WHERE session_token = %s",
                (session_token,)
            )
            conn.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")
        return {"ok": True}
    finally:
        conn.close()
