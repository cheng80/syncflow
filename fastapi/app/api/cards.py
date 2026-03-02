"""
SyncFlow 카드 API
카드 생성, 수정, 아카이브
REST 성공 시 WebSocket broadcast (실시간 동기화)
"""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.database.connection import connect_db
from app.utils.auth_deps import get_current_user_id
from app.ws.room import broadcast_to_board

router = APIRouter()


def _ts_ms() -> int:
    return int(datetime.utcnow().timestamp() * 1000)


def _check_board_member(cursor, board_id: int, user_id: int) -> None:
    cursor.execute(
        "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
        (board_id, user_id),
    )
    if not cursor.fetchone():
        raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")


class CreateCardRequest(BaseModel):
    title: str
    description: str | None = None
    column_id: int
    priority: str = "medium"


class UpdateCardRequest(BaseModel):
    title: str | None = None
    description: str | None = None
    column_id: int | None = None
    priority: str | None = None
    position: int | None = None  # 같은 컬럼 내 재정렬용


@router.post("")
async def create_card(
    req: CreateCardRequest,
    user_id: int = Depends(get_current_user_id),
):
    """카드 생성"""
    if not req.title or not req.title.strip():
        raise HTTPException(status_code=400, detail="제목을 입력하세요.")

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT board_id FROM columns WHERE id = %s",
                (req.column_id,),
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="컬럼을 찾을 수 없습니다.")
            board_id = row[0]

            _check_board_member(cursor, board_id, user_id)

            # 신규 카드는 컬럼 맨 위에 삽입
            cursor.execute(
                "SELECT MIN(position) FROM cards WHERE column_id = %s AND status = 'active'",
                (req.column_id,),
            )
            min_pos = cursor.fetchone()[0]
            position = (min_pos - 1000) if min_pos is not None else 0

            priority = req.priority if req.priority in ("low", "medium", "high") else "medium"

            cursor.execute(
                """
                INSERT INTO cards (board_id, column_id, title, description, priority, status, position, created_by, updated_by)
                VALUES (%s, %s, %s, %s, %s, 'active', %s, %s, %s)
                """,
                (
                    board_id,
                    req.column_id,
                    req.title.strip(),
                    (req.description or "").strip() or None,
                    priority,
                    position,
                    user_id,
                    user_id,
                ),
            )
            card_id = cursor.lastrowid
            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            cursor.execute("SELECT UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s", (board_id,))
            board_version = int(cursor.fetchone()[0])
            conn.commit()

        result = {
            "id": card_id,
            "column_id": req.column_id,
            "title": req.title.strip(),
            "description": req.description or "",
            "priority": priority,
            "status": "active",
            "position": position,
        }
        await broadcast_to_board(board_id, {
            "type": "CARD_CREATED",
            "data": {"board_id": board_id, "card": {**result, "updated_at": _ts_ms()}, "board_version": board_version},
        })
        return result
    finally:
        conn.close()


@router.patch("/{card_id}")
async def update_card(
    card_id: int,
    req: UpdateCardRequest,
    user_id: int = Depends(get_current_user_id),
):
    """카드 수정 (제목, 설명, 컬럼, 우선순위)"""
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT board_id, column_id FROM cards WHERE id = %s AND status = 'active'",
                (card_id,),
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="카드를 찾을 수 없습니다.")
            board_id, old_column_id = row

            _check_board_member(cursor, board_id, user_id)

            updates = []
            params = []
            target_column_id = old_column_id

            if req.title is not None and req.title.strip():
                updates.append("title = %s")
                params.append(req.title.strip())
            if req.description is not None:
                updates.append("description = %s")
                params.append(req.description.strip() or None)
            if req.column_id is not None:
                cursor.execute(
                    "SELECT 1 FROM columns WHERE id = %s AND board_id = %s",
                    (req.column_id, board_id),
                )
                if not cursor.fetchone():
                    raise HTTPException(status_code=400, detail="유효하지 않은 컬럼입니다.")
                cursor.execute(
                    "SELECT COALESCE(MAX(position), 0) + 1000 FROM cards WHERE column_id = %s",
                    (req.column_id,),
                )
                new_pos = cursor.fetchone()[0]
                updates.append("column_id = %s")
                params.append(req.column_id)
                updates.append("position = %s")
                params.append(new_pos)
                target_column_id = req.column_id
            if req.priority is not None and req.priority in ("low", "medium", "high"):
                updates.append("priority = %s")
                params.append(req.priority)
            if req.position is not None:
                updates.append("position = %s")
                params.append(req.position)

            if not updates:
                cursor.execute(
                    "SELECT id, column_id, title, description, priority, status, position FROM cards WHERE id = %s",
                    (card_id,),
                )
                r = cursor.fetchone()
                return {
                    "id": r[0],
                    "column_id": r[1],
                    "title": r[2],
                    "description": r[3] or "",
                    "priority": r[4],
                    "status": r[5],
                    "position": r[6],
                }

            updates.append("updated_by = %s")
            params.append(user_id)
            params.append(card_id)
            cursor.execute(
                f"UPDATE cards SET {', '.join(updates)} WHERE id = %s",
                params,
            )

            # position 변경이 있으면 WS 경로와 동일하게 컬럼 내 1000 단위로 재정렬
            affected_columns = set()
            if req.position is not None or req.column_id is not None:
                affected_columns.add(target_column_id)
            if req.column_id is not None and old_column_id != target_column_id:
                affected_columns.add(old_column_id)

            for col_id in affected_columns:
                cursor.execute(
                    """SELECT id FROM cards
                       WHERE column_id = %s AND board_id = %s AND status = 'active'
                       ORDER BY position, id""",
                    (col_id, board_id),
                )
                for i, (cid,) in enumerate(cursor.fetchall()):
                    cursor.execute("UPDATE cards SET position = %s WHERE id = %s", (i * 1000, cid))

            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            cursor.execute("SELECT UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s", (board_id,))
            board_version = int(cursor.fetchone()[0])

            conn.commit()

            cursor.execute(
                "SELECT id, column_id, title, description, priority, status, position FROM cards WHERE id = %s",
                (card_id,),
            )
            r = cursor.fetchone()
            result = {
                "id": r[0],
                "column_id": r[1],
                "title": r[2],
                "description": r[3] or "",
                "priority": r[4],
                "status": r[5],
                "position": r[6],
            }
        patch = {}
        if req.title is not None:
            patch["title"] = result["title"]
        if req.description is not None:
            patch["description"] = result["description"]
        if req.column_id is not None:
            patch["column_id"] = result["column_id"]
            patch["position"] = result["position"]
        if req.priority is not None:
            patch["priority"] = result["priority"]
        if req.position is not None:
            patch["position"] = result["position"]
        if patch:
            await broadcast_to_board(board_id, {
                "type": "CARD_UPDATED",
                "data": {
                    "board_id": board_id,
                    "card_id": card_id,
                    "patch": patch,
                    "updated_at": _ts_ms(),
                    "board_version": board_version,
                },
            })
        return result
    finally:
        conn.close()


@router.delete("/{card_id}")
async def archive_card(
    card_id: int,
    user_id: int = Depends(get_current_user_id),
):
    """카드 아카이브 (status=archived, 물리 삭제 아님)"""
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT board_id FROM cards WHERE id = %s",
                (card_id,),
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="카드를 찾을 수 없습니다.")
            board_id = row[0]

            _check_board_member(cursor, board_id, user_id)

            cursor.execute(
                "UPDATE cards SET status = 'archived', updated_by = %s WHERE id = %s",
                (user_id, card_id),
            )
            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            cursor.execute("SELECT UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s", (board_id,))
            board_version = int(cursor.fetchone()[0])
            conn.commit()

        await broadcast_to_board(board_id, {
            "type": "CARD_ARCHIVED",
            "data": {
                "board_id": board_id,
                "card_id": card_id,
                "status": "archived",
                "updated_at": _ts_ms(),
                "board_version": board_version,
            },
        })
        return {"ok": True}
    finally:
        conn.close()
