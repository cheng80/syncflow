"""
SyncFlow 인증 API
이메일 6자리 코드 인증 → UUID4 세션 토큰 (14일)
"""

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr

from app.database.connection import connect_db
from app.utils.auth_deps import get_current_user_id
from app.utils.email_service import EmailService

router = APIRouter()


@router.get("/me")
async def get_me(user_id: int = Depends(get_current_user_id)):
    """현재 로그인 사용자 정보 (X-Session-Token 필요)"""
    return {"user_id": user_id}


CODE_EXPIRES_MINUTES = 10
RESEND_COOLDOWN_SECONDS = 60
MAX_ATTEMPTS = 5
SESSION_EXPIRES_DAYS = 14


def _generate_code() -> str:
    """6자리 숫자 코드 생성"""
    return "".join(secrets.choice("0123456789") for _ in range(6))


def _hash_code(code: str) -> str:
    """SHA256 해시"""
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


class SendCodeRequest(BaseModel):
    email: EmailStr


class VerifyRequest(BaseModel):
    email: EmailStr
    code: str


@router.post("/send-code")
async def send_code(req: SendCodeRequest):
    """
    이메일로 6자리 인증 코드 발송
    - email_verifications에 code_hash 저장
    - 이메일 발송
    """
    email = str(req.email).lower().strip()
    code = _generate_code()
    code_hash = _hash_code(code)
    expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=CODE_EXPIRES_MINUTES)

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                f"""
                SELECT id,
                       LEAST(
                           {RESEND_COOLDOWN_SECONDS},
                           GREATEST(
                               0,
                               {RESEND_COOLDOWN_SECONDS} - TIMESTAMPDIFF(SECOND, created_at, UTC_TIMESTAMP())
                           )
                       ) AS retry_after
                FROM email_verifications
                WHERE email = %s
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                FOR UPDATE
                """,
                (email,)
            )
            latest = cursor.fetchone()
            retry_after = int(latest[1]) if latest else 0
            if retry_after > 0:
                raise HTTPException(
                    status_code=429,
                    detail=f"인증 코드는 {retry_after}초 후 다시 요청할 수 있습니다.",
                    headers={"Retry-After": str(retry_after)},
                )

            cursor.execute(
                """
                INSERT INTO email_verifications (email, code_hash, expires_at, attempt_count)
                VALUES (%s, %s, %s, 0)
                """,
                (email, code_hash, expires_at)
            )
            verification_id = cursor.lastrowid
            cursor.execute(
                "DELETE FROM email_verifications WHERE email = %s AND id <> %s",
                (email, verification_id),
            )
            conn.commit()

        if not EmailService.send_login_code(email, code, CODE_EXPIRES_MINUTES):
            with conn.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM email_verifications WHERE id = %s",
                    (verification_id,),
                )
                conn.commit()
            raise HTTPException(status_code=500, detail="이메일 발송 실패")

        return {"ok": True, "message": "인증 코드가 발송되었습니다."}
    finally:
        conn.close()


@router.post("/verify")
async def verify(req: VerifyRequest):
    """
    인증 코드 검증 → users 생성/조회 → sessions 생성 → session_token 반환
    """
    email = str(req.email).lower().strip()
    code = req.code.strip()

    if len(code) != 6 or not code.isdigit():
        raise HTTPException(status_code=400, detail="인증 코드는 6자리 숫자여야 합니다.")

    code_hash = _hash_code(code)
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, code_hash, attempt_count FROM email_verifications
                WHERE email = %s AND expires_at > UTC_TIMESTAMP()
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                FOR UPDATE
                """,
                (email,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=400, detail="인증 코드가 올바르지 않거나 만료되었습니다.")

            ev_id, stored_code_hash, attempt_count = row
            if attempt_count >= MAX_ATTEMPTS:
                raise HTTPException(status_code=400, detail="시도 횟수 초과. 새 코드를 요청하세요.")

            if not hmac.compare_digest(code_hash, stored_code_hash):
                cursor.execute(
                    """
                    UPDATE email_verifications
                    SET attempt_count = attempt_count + 1
                    WHERE id = %s
                    """,
                    (ev_id,),
                )
                conn.commit()
                if attempt_count + 1 >= MAX_ATTEMPTS:
                    raise HTTPException(status_code=400, detail="시도 횟수 초과. 새 코드를 요청하세요.")
                raise HTTPException(status_code=400, detail="인증 코드가 올바르지 않거나 만료되었습니다.")

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
            expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=SESSION_EXPIRES_DAYS)

            cursor.execute(
                """
                INSERT INTO sessions (user_id, session_token, expires_at)
                VALUES (%s, %s, %s)
                """,
                (user_id, session_token, expires_at)
            )
            # 사용한 인증 코드 무효화
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


@router.delete("/me")
async def delete_me(user_id: int = Depends(get_current_user_id)):
    """
    회원 탈퇴 (사용자 및 연관 데이터 삭제)
    - users 삭제 시 FK CASCADE로 boards/board_members/sessions/cards 등 정리
    """
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
            conn.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        return {"ok": True}
    finally:
        conn.close()
