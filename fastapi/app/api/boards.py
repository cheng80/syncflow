"""
SyncFlow 보드 API
보드 목록, 생성, 상세(컬럼+카드), 멤버 초대
"""

import secrets

from app.ws.room import broadcast_to_board
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.database.connection import connect_db
from app.utils.auth_deps import get_current_user_id

router = APIRouter()


def _check_board_owner(cursor, board_id: int, user_id: int) -> None:
    cursor.execute(
        "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s AND role = 'owner'",
        (board_id, user_id),
    )
    if not cursor.fetchone():
        raise HTTPException(status_code=403, detail="보드 소유자만 초대할 수 있습니다.")


class CreateBoardRequest(BaseModel):
    title: str
    template: str = "todo"

# 템플릿: Todo, Doing, Done
TEMPLATE_TODO = [
    {"title": "할 일", "position": 1000, "is_done": False},
    {"title": "진행 중", "position": 2000, "is_done": False},
    {"title": "완료", "position": 3000, "is_done": True},
]

# 템플릿: 단일 컬럼 (간단)
TEMPLATE_SIMPLE = [
    {"title": "작업", "position": 1000, "is_done": False},
]


@router.get("")
async def list_boards(user_id: int = Depends(get_current_user_id)):
    """
    내 보드 목록 (owner 또는 member)
    """
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT b.id, b.title, b.owner_id, b.created_at
                FROM boards b
                INNER JOIN board_members bm ON b.id = bm.board_id
                WHERE bm.user_id = %s
                ORDER BY b.updated_at DESC
                """,
                (user_id,),
            )
            rows = cursor.fetchall()
            return [
                {
                    "id": r[0],
                    "title": r[1],
                    "owner_id": r[2],
                    "created_at": r[3].isoformat() + "Z" if r[3] else None,
                }
                for r in rows
            ]
    finally:
        conn.close()


@router.post("")
async def create_board(
    req: CreateBoardRequest,
    user_id: int = Depends(get_current_user_id),
):
    """
    보드 생성 (템플릿에 따라 컬럼 자동 생성)
    template: "todo" = 할 일/진행 중/완료, "simple" = 단일 컬럼
    """
    if not req.title or not req.title.strip():
        raise HTTPException(status_code=400, detail="제목을 입력하세요.")

    columns_data = TEMPLATE_SIMPLE if req.template == "simple" else TEMPLATE_TODO

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO boards (owner_id, title) VALUES (%s, %s)",
                (user_id, req.title.strip()),
            )
            board_id = cursor.lastrowid

            cursor.execute(
                "INSERT INTO board_members (board_id, user_id, role) VALUES (%s, %s, 'owner')",
                (board_id, user_id),
            )

            for col in columns_data:
                cursor.execute(
                    """
                    INSERT INTO columns (board_id, title, position, is_done)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (board_id, col["title"], col["position"], col["is_done"]),
                )

            conn.commit()

        return {"id": board_id, "title": req.title.strip(), "owner_id": user_id}
    finally:
        conn.close()


class JoinBoardRequest(BaseModel):
    code: str


class CreateColumnRequest(BaseModel):
    title: str
    is_done: bool = False


class UpdateColumnRequest(BaseModel):
    title: str | None = None
    is_done: bool | None = None
    position: int | None = None


@router.post("/join")
async def join_board_by_code(
    req: JoinBoardRequest,
    user_id: int = Depends(get_current_user_id),
):
    """
    초대 코드로 보드 참가
    """
    code = (req.code or "").strip().upper()
    if len(code) != 6:
        raise HTTPException(status_code=400, detail="초대 코드는 6자리입니다.")

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT bi.id, bi.board_id, bi.used_count, bi.max_uses
                FROM board_invites bi
                WHERE bi.code = %s
                  AND bi.revoked = FALSE
                  AND bi.expires_at > UTC_TIMESTAMP()
                """,
                (code,),
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=400, detail="유효하지 않거나 만료된 초대 코드입니다.")

            inv_id, board_id, used_count, max_uses = row
            if used_count >= max_uses:
                raise HTTPException(status_code=400, detail="초대 코드 사용 한도 초과입니다.")

            # 이미 멤버인지 확인
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if cursor.fetchone():
                cursor.execute("SELECT title FROM boards WHERE id = %s", (board_id,))
                title = cursor.fetchone()[0]
                return {"board_id": board_id, "title": title, "message": "이미 참여 중인 보드입니다."}

            # 멤버 추가
            cursor.execute(
                "INSERT INTO board_members (board_id, user_id, role) VALUES (%s, %s, 'member')",
                (board_id, user_id),
            )
            cursor.execute(
                "UPDATE board_invites SET used_count = used_count + 1 WHERE id = %s",
                (inv_id,),
            )
            conn.commit()

            cursor.execute("SELECT title FROM boards WHERE id = %s", (board_id,))
            title = cursor.fetchone()[0]
            return {"board_id": board_id, "title": title}
    finally:
        conn.close()


def _normalize_column_positions(cursor, board_id: int) -> None:
    cursor.execute(
        "SELECT id FROM columns WHERE board_id = %s ORDER BY position, id",
        (board_id,),
    )
    for i, (col_id,) in enumerate(cursor.fetchall()):
        cursor.execute("UPDATE columns SET position = %s WHERE id = %s", (i * 1000, col_id))


@router.post("/{board_id}/columns")
async def create_column(
    board_id: int,
    req: CreateColumnRequest,
    user_id: int = Depends(get_current_user_id),
):
    title = (req.title or "").strip()
    if not title:
        raise HTTPException(status_code=400, detail="컬럼 제목을 입력하세요.")

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            cursor.execute(
                "SELECT COALESCE(MAX(position), -1000) + 1000 FROM columns WHERE board_id = %s",
                (board_id,),
            )
            new_pos = int(cursor.fetchone()[0])
            cursor.execute(
                "INSERT INTO columns (board_id, title, position, is_done) VALUES (%s, %s, %s, %s)",
                (board_id, title, new_pos, req.is_done),
            )
            col_id = cursor.lastrowid
            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            conn.commit()
            return {"id": col_id, "title": title, "position": new_pos, "is_done": req.is_done}
    finally:
        conn.close()


@router.patch("/{board_id}/columns/{column_id}")
async def update_column(
    board_id: int,
    column_id: int,
    req: UpdateColumnRequest,
    user_id: int = Depends(get_current_user_id),
):
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            cursor.execute(
                "SELECT id FROM columns WHERE id = %s AND board_id = %s",
                (column_id, board_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="컬럼을 찾을 수 없습니다.")

            updates = []
            params = []
            if req.title is not None:
                title = req.title.strip()
                if not title:
                    raise HTTPException(status_code=400, detail="컬럼 제목을 입력하세요.")
                updates.append("title = %s")
                params.append(title)
            if req.is_done is not None:
                updates.append("is_done = %s")
                params.append(req.is_done)
            if req.position is not None:
                updates.append("position = %s")
                params.append(req.position)

            if not updates:
                raise HTTPException(status_code=400, detail="수정할 항목이 없습니다.")

            params.append(column_id)
            cursor.execute(f"UPDATE columns SET {', '.join(updates)} WHERE id = %s", params)

            if req.position is not None:
                _normalize_column_positions(cursor, board_id)

            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            conn.commit()

            cursor.execute(
                "SELECT id, title, position, is_done FROM columns WHERE id = %s",
                (column_id,),
            )
            col = cursor.fetchone()
            return {
                "id": col[0],
                "title": col[1],
                "position": col[2],
                "is_done": bool(col[3]),
            }
    finally:
        conn.close()


@router.delete("/{board_id}/columns/{column_id}")
async def delete_column(
    board_id: int,
    column_id: int,
    user_id: int = Depends(get_current_user_id),
):
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            cursor.execute(
                "SELECT id, position FROM columns WHERE board_id = %s ORDER BY position, id",
                (board_id,),
            )
            rows = cursor.fetchall()
            if not rows:
                raise HTTPException(status_code=404, detail="컬럼을 찾을 수 없습니다.")
            if len(rows) <= 1:
                raise HTTPException(status_code=400, detail="컬럼은 최소 1개 이상 있어야 합니다.")

            ordered_ids = [r[0] for r in rows]
            if column_id not in ordered_ids:
                raise HTTPException(status_code=404, detail="컬럼을 찾을 수 없습니다.")

            idx = ordered_ids.index(column_id)
            fallback_id = ordered_ids[idx - 1] if idx > 0 else ordered_ids[idx + 1]

            cursor.execute(
                "UPDATE cards SET column_id = %s, updated_by = %s WHERE board_id = %s AND column_id = %s AND status = 'active'",
                (fallback_id, user_id, board_id, column_id),
            )
            moved_count = cursor.rowcount

            cursor.execute("DELETE FROM columns WHERE id = %s", (column_id,))
            _normalize_column_positions(cursor, board_id)
            cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
            conn.commit()

            return {
                "ok": True,
                "fallback_column_id": fallback_id,
                "moved_card_count": moved_count,
            }
    finally:
        conn.close()


class UpdateBoardRequest(BaseModel):
    title: str | None = None


@router.patch("/{board_id}")
async def update_board(
    board_id: int,
    req: UpdateBoardRequest,
    user_id: int = Depends(get_current_user_id),
):
    """
    보드 수정 (owner만) - 제목 변경
    """
    if req.title is None or not req.title.strip():
        raise HTTPException(status_code=400, detail="제목을 입력하세요.")

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            cursor.execute(
                "SELECT owner_id FROM boards WHERE id = %s",
                (board_id,),
            )
            row = cursor.fetchone()
            owner_id = row[0] if row else user_id

            cursor.execute(
                "UPDATE boards SET title = %s, updated_at = UTC_TIMESTAMP() WHERE id = %s",
                (req.title.strip(), board_id),
            )
            conn.commit()
            result = {"id": board_id, "title": req.title.strip(), "owner_id": owner_id}
    finally:
        conn.close()

    await broadcast_to_board(
        board_id,
        {
            "type": "BOARD_UPDATED",
            "data": {"board_id": board_id, "title": req.title.strip()},
        },
    )
    return result


@router.delete("/{board_id}")
async def delete_board(
    board_id: int,
    user_id: int = Depends(get_current_user_id),
):
    """
    보드 삭제 (owner만)
    """
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            cursor.execute("DELETE FROM boards WHERE id = %s", (board_id,))
            conn.commit()

            # 참여 중인 멤버에게 BOARD_DELETED 브로드캐스트
            await broadcast_to_board(
                board_id,
                {"type": "BOARD_DELETED", "data": {"board_id": board_id}},
            )

            return {"ok": True}
    finally:
        conn.close()


@router.get("/{board_id}")
async def get_board_detail(
    board_id: int,
    user_id: int = Depends(get_current_user_id),
):
    """
    보드 상세 (컬럼 + 카드)
    board_members에 있어야 접근 가능
    """
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")

            cursor.execute(
                "SELECT id, title, owner_id, UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s",
                (board_id,),
            )
            board_row = cursor.fetchone()
            if not board_row:
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")

            bid, btitle, owner_id, board_version = board_row

            cursor.execute(
                """
                SELECT id, title, position, is_done
                FROM columns WHERE board_id = %s ORDER BY position
                """,
                (board_id,),
            )
            columns = [
                {
                    "id": r[0],
                    "title": r[1],
                    "position": r[2],
                    "is_done": bool(r[3]),
                }
                for r in cursor.fetchall()
            ]

            cursor.execute(
                """
                SELECT id, column_id, title, description, priority, assignee_id, due_date, status, position
                FROM cards
                WHERE board_id = %s AND status = 'active'
                ORDER BY column_id, position
                """,
                (board_id,),
            )
            cards = [
                {
                    "id": r[0],
                    "column_id": r[1],
                    "title": r[2],
                    "description": r[3] or "",
                    "priority": r[4],
                    "assignee_id": r[5],
                    "due_date": r[6].isoformat() + "Z" if r[6] else None,
                    "status": r[7],
                    "position": r[8],
                }
                for r in cursor.fetchall()
            ]

        return {
            "id": bid,
            "title": btitle,
            "owner_id": owner_id,
            "board_version": int(board_version) if board_version is not None else None,
            "columns": columns,
            "cards": cards,
        }
    finally:
        conn.close()


def _generate_invite_code() -> str:
    """6자리 대문자+숫자 코드"""
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(chars) for _ in range(6))


@router.post("/{board_id}/invite")
async def create_invite(
    board_id: int,
    user_id: int = Depends(get_current_user_id),
):
    """
    초대 코드 생성 (owner만)
    기존 유효 코드가 있으면 반환
    """
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                (board_id, user_id),
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="보드를 찾을 수 없습니다.")
            _check_board_owner(cursor, board_id, user_id)

            expires_at = datetime.utcnow() + timedelta(days=7)

            # 유효한 기존 코드 확인
            cursor.execute(
                """
                SELECT code, expires_at FROM board_invites
                WHERE board_id = %s AND revoked = FALSE
                  AND expires_at > UTC_TIMESTAMP()
                  AND used_count < max_uses
                ORDER BY created_at DESC LIMIT 1
                """,
                (board_id,),
            )
            row = cursor.fetchone()
            if row:
                return {"code": row[0], "expires_at": row[1].isoformat() + "Z"}

            # 새 코드 생성 (충돌 시 재시도)
            for _ in range(5):
                code = _generate_invite_code()
                try:
                    cursor.execute(
                        """
                        INSERT INTO board_invites (board_id, code, created_by, expires_at)
                        VALUES (%s, %s, %s, %s)
                        """,
                        (board_id, code, user_id, expires_at),
                    )
                    conn.commit()
                    return {"code": code, "expires_at": expires_at.isoformat() + "Z"}
                except Exception:
                    conn.rollback()
                    continue
            raise HTTPException(status_code=500, detail="초대 코드 생성 실패")
    finally:
        conn.close()
