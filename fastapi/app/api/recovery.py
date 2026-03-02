"""
복구용 이메일 등록 API - 6자리 인증 코드
다른 기기 복구: 이메일로 백업 조회
"""

import hashlib
import json
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.database.connection import connect_db
from app.utils.email_service import EmailService

router = APIRouter()


class EmailRequestBody(BaseModel):
    device_uuid: str
    email: str


class EmailVerifyBody(BaseModel):
    device_uuid: str
    email: str
    code: str

CODE_EXPIRES_MINUTES = 10
MAX_ATTEMPTS = 5


def _generate_code() -> str:
    """6자리 숫자 코드 생성"""
    return "".join(secrets.choice("0123456789") for _ in range(6))


def _hash_code(code: str) -> str:
    """SHA256 해시"""
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


@router.get("/status")
async def get_recovery_status(device_uuid: str):
    """
    이메일 인증 여부 + 서버 저장 백업 여부 조회
    - Flutter에서 백업 화면 진입 시 호출
    - has_backup, last_backup_at: 동일 이메일로 인증된 기기들의 백업 중 최신 1건
      (다른 기기에서 백업한 자료도 이 기기에서 복구 가능하므로, 이메일 기준으로 조회)
    """
    if not device_uuid:
        raise HTTPException(status_code=400, detail="device_uuid required")

    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT email, email_verified_at
            FROM devices
            WHERE device_uuid = %s
            """,
            (device_uuid,),
        )
        row = cursor.fetchone()
        if not row:
            return {"email_verified": False, "email": None, "has_backup": False, "last_backup_at": None}
        email, email_verified_at = row

        # 이메일 인증된 경우: 동일 이메일로 인증된 모든 기기들의 백업 중 최신 1건 조회
        # (복구 API와 동일한 기준 - 다른 기기 백업도 이 기기에서 복구 가능)
        if email_verified_at is not None:
            cursor.execute(
                """
                SELECT b.payload_updated_at
                FROM backups b
                JOIN devices d ON b.device_uuid = d.device_uuid
                WHERE d.email = %s AND d.email_verified_at IS NOT NULL
                ORDER BY b.payload_updated_at DESC
                LIMIT 1
                """,
                (email,),
            )
        else:
            cursor.execute(
                """
                SELECT payload_updated_at FROM backups WHERE device_uuid = %s
                """,
                (device_uuid,),
            )
        backup_row = cursor.fetchone()
        has_backup = backup_row is not None
        last_backup_at = None
        if backup_row and backup_row[0]:
            dt = backup_row[0]
            last_backup_at = dt.isoformat() if hasattr(dt, "isoformat") else str(dt)

        return {
            "email_verified": email_verified_at is not None,
            "email": email,
            "has_backup": has_backup,
            "last_backup_at": last_backup_at,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/email/request")
async def request_email_verification(body: EmailRequestBody):
    """
    이메일 인증 코드 요청
    - 6자리 코드 생성 → SHA256 해시 저장 → 이메일 발송
    """
    device_uuid = body.device_uuid
    email = body.email
    if not device_uuid:
        raise HTTPException(status_code=400, detail="device_uuid required")
    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="valid email required")

    email = email.strip().lower()
    code = _generate_code()
    code_hash = _hash_code(code)
    expires_at = datetime.utcnow() + timedelta(minutes=CODE_EXPIRES_MINUTES)

    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()

        # devices에 없으면 INSERT
        cursor.execute(
            """
            INSERT INTO devices (device_uuid) VALUES (%s)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
            """,
            (device_uuid,),
        )

        # 기존 미만료 인증 삭제 (같은 device+email)
        cursor.execute(
            """
            DELETE FROM email_verifications
            WHERE device_uuid = %s AND email = %s
            """,
            (device_uuid, email),
        )

        # 새 인증 레코드 삽입
        cursor.execute(
            """
            INSERT INTO email_verifications (device_uuid, email, code_hash, expires_at, attempt_count)
            VALUES (%s, %s, %s, %s, 0)
            """,
            (device_uuid, email, code_hash, expires_at.strftime("%Y-%m-%d %H:%M:%S")),
        )

        conn.commit()

        # 이메일 발송
        ok = EmailService.send_verification_code(to_email=email, code=code, expires_minutes=CODE_EXPIRES_MINUTES)
        if not ok:
            # DB는 저장됐지만 이메일 실패 - 클라이언트에선 재시도 유도
            raise HTTPException(status_code=503, detail="이메일 발송에 실패했습니다. 잠시 후 다시 시도해 주세요.")

        return {"status": "ok", "message": "인증 코드가 발송되었습니다."}
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.post("/email/verify")
async def verify_email_code(body: EmailVerifyBody):
    """
    이메일 인증 코드 검증
    - code_hash 일치 시 devices.email, email_verified_at 업데이트
    """
    device_uuid = body.device_uuid
    email = body.email
    code = body.code
    if not device_uuid:
        raise HTTPException(status_code=400, detail="device_uuid required")
    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="valid email required")
    if not code or len(code) != 6 or not code.isdigit():
        raise HTTPException(status_code=400, detail="6자리 숫자 코드를 입력해 주세요.")

    email = email.strip().lower()
    code_hash = _hash_code(code.strip())

    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT id, attempt_count, expires_at
            FROM email_verifications
            WHERE device_uuid = %s AND email = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (device_uuid, email),
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=400, detail="인증 코드를 먼저 요청해 주세요.")

        ev_id, attempt_count, expires_at = row
        if attempt_count >= MAX_ATTEMPTS:
            cursor.execute("DELETE FROM email_verifications WHERE id = %s", (ev_id,))
            conn.commit()
            raise HTTPException(status_code=400, detail="시도 횟수를 초과했습니다. 새 인증 코드를 요청해 주세요.")

        if expires_at and datetime.utcnow() > expires_at:
            raise HTTPException(status_code=400, detail="인증 코드가 만료되었습니다. 새 인증 코드를 요청해 주세요.")

        cursor.execute(
            "SELECT code_hash FROM email_verifications WHERE id = %s",
            (ev_id,),
        )
        stored_hash = cursor.fetchone()[0]
        if stored_hash != code_hash:
            cursor.execute(
                "UPDATE email_verifications SET attempt_count = attempt_count + 1 WHERE id = %s",
                (ev_id,),
            )
            conn.commit()
            raise HTTPException(status_code=400, detail="인증 코드가 일치하지 않습니다.")

        # 인증 성공: devices 업데이트, 사용한 인증 레코드 삭제
        now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        cursor.execute(
            """
            UPDATE devices
            SET email = %s, email_verified_at = %s, updated_at = %s
            WHERE device_uuid = %s
            """,
            (email, now, now, device_uuid),
        )
        cursor.execute("DELETE FROM email_verifications WHERE id = %s", (ev_id,))
        conn.commit()

        return {"status": "ok", "message": "이메일이 등록되었습니다."}
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/backup")
async def get_backup_by_email(device_uuid: str):
    """
    다른 기기 복구용: 이메일로 백업 조회
    - device_uuid의 devices.email이 인증된 경우, 해당 이메일로 등록된 기기들의 백업 중 최신 1개 반환
    """
    if not device_uuid:
        raise HTTPException(status_code=400, detail="device_uuid required")

    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()

        # 현재 기기의 이메일 인증 여부 확인
        cursor.execute(
            """
            SELECT email FROM devices
            WHERE device_uuid = %s AND email_verified_at IS NOT NULL
            """,
            (device_uuid,),
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(
                status_code=403,
                detail="이메일 인증이 필요합니다. 백업 화면에서 이메일을 등록해 주세요.",
            )

        email = row[0]

        # 동일 이메일로 인증된 기기들의 백업 중 최신 1개 조회
        cursor.execute(
            """
            SELECT b.payload_json, b.checksum, b.payload_updated_at
            FROM backups b
            JOIN devices d ON b.device_uuid = d.device_uuid
            WHERE d.email = %s AND d.email_verified_at IS NOT NULL
            ORDER BY b.payload_updated_at DESC
            LIMIT 1
            """,
            (email,),
        )
        backup_row = cursor.fetchone()
        if not backup_row:
            raise HTTPException(status_code=404, detail="No backup found for this email")

        payload_json, checksum, payload_updated_at = backup_row
        payload = json.loads(payload_json)
        return {
            "payload": payload,
            "checksum": checksum,
            "payload_updated_at": payload_updated_at,
        }
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
