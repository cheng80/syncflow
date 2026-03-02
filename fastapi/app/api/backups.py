"""
백업 API - SQLite 스냅샷 업로드/다운로드
"""

import hashlib
import json
from datetime import datetime
from fastapi import APIRouter, HTTPException

from app.database.connection import connect_db

router = APIRouter()


def _iso8601_to_mysql_datetime(iso: str) -> str:
    """ISO8601 → MySQL DATETIME (YYYY-MM-DD HH:MM:SS)"""
    if not iso:
        return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")


@router.post("")
async def upsert_backup(payload: dict):
    """
    백업 업서트 (device_uuid당 최신 1개)
    - payload 내 device_uuid 사용
    - devices 테이블에 device 없으면 INSERT
    - backups 테이블 UPSERT (ON DUPLICATE KEY UPDATE)
    """
    device_uuid = payload.get("device_uuid")
    if not device_uuid:
        raise HTTPException(status_code=400, detail="device_uuid required in payload")
    payload_json = json.dumps(payload, ensure_ascii=False)
    checksum = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
    exported_at = _iso8601_to_mysql_datetime(payload.get("exported_at", ""))

    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()

        # devices에 device_uuid 없으면 INSERT (이메일은 NULL)
        cursor.execute(
            """
            INSERT INTO devices (device_uuid) VALUES (%s)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
            """,
            (device_uuid,),
        )

        # backups UPSERT
        cursor.execute(
            """
            INSERT INTO backups (device_uuid, payload_json, checksum, payload_updated_at)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                payload_json = VALUES(payload_json),
                checksum = VALUES(checksum),
                payload_updated_at = VALUES(payload_updated_at),
                updated_at = CURRENT_TIMESTAMP
            """,
            (device_uuid, payload_json, checksum, exported_at),
        )

        conn.commit()
        return {"status": "ok", "device_uuid": device_uuid}
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()


@router.get("/latest")
async def get_latest_backup(device_uuid: str):
    """
    최신 백업 조회
    """
    conn = None
    try:
        conn = connect_db()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT payload_json, checksum, payload_updated_at
            FROM backups
            WHERE device_uuid = %s
            """,
            (device_uuid,),
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="No backup found")

        payload_json, checksum, payload_updated_at = row
        payload = json.loads(payload_json)
        return {
            "payload": payload,
            "checksum": checksum,
            "payload_updated_at": payload_updated_at,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
