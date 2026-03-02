"""
WebSocket 메시지 핸들러
JOIN_BOARD, LEAVE_BOARD, CARD_* 이벤트 처리
"""

import json
import time
from datetime import datetime
from fastapi import WebSocket

from app.database.connection import connect_db
from app.ws.room import join_room, leave_room, leave_all_rooms, broadcast_to_board, get_room_members
from app.ws.lock import acquire_lock, renew_lock, release_lock, release_locks_by_user

# ws -> set of board_ids (현재 참여 중인 보드)
_ws_boards: dict[WebSocket, set[int]] = {}


def _get_user_display(cursor, user_id: int) -> str:
    email = _get_user_email(cursor, user_id)
    if email:
        return _to_short_display(email)
    return f"user_{user_id}"


def _get_user_email(cursor, user_id: int) -> str:
    cursor.execute("SELECT email FROM users WHERE id = %s", (user_id,))
    row = cursor.fetchone()
    return (row[0] or "") if row else ""


def _to_short_display(email: str) -> str:
    if "@" in email:
        local, domain = email.split("@", 1)
        domain_head = domain.split(".", 1)[0]
        return f"{local}@{domain_head}"
    return email


def _check_board_member(cursor, board_id: int, user_id: int) -> bool:
    cursor.execute(
        "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
        (board_id, user_id),
    )
    return cursor.fetchone() is not None


def _get_online_members(board_id: int) -> list[dict]:
    """현재 온라인 멤버 목록 (user_id, display) - DB에서 조회"""
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            members = []
            for ws in get_room_members(board_id):
                uid = getattr(ws, "_user_id", None)
                if uid is not None:
                    email = _get_user_email(cursor, uid)
                    members.append({
                        "user_id": uid,
                        "display": _to_short_display(email) if email else f"user_{uid}",
                        "email": email,
                    })
            return members
    finally:
        conn.close()


async def _send_error(
    ws: WebSocket,
    code: str,
    message: str,
    req_id: str | None = None,
    detail: dict | None = None,
) -> None:
    payload = {
        "type": "ERROR",
        "data": {"code": code, "message": message, "detail": detail or {}},
    }
    if req_id:
        payload["req_id"] = req_id
    await ws.send_json(payload)


async def _handle_join_board(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    if board_id is None:
        await _send_error(ws, "VALIDATION_ERROR", "board_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id는 정수여야 합니다", req_id)
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
    finally:
        conn.close()

    # 룸 참가
    setattr(ws, "_user_id", user_id)
    join_room(board_id, ws)
    if ws not in _ws_boards:
        _ws_boards[ws] = set()
    _ws_boards[ws].add(board_id)

    # BOARD_JOINED ACK
    members_online = _get_online_members(board_id)

    ack = {
        "type": "BOARD_JOINED",
        "data": {"board_id": board_id, "members_online": members_online},
    }
    if req_id:
        ack["req_id"] = req_id
    await ws.send_json(ack)

    # PRESENCE_JOINED broadcast (다른 클라이언트에게)
    display = None
    email = ""
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            email = _get_user_email(cursor, user_id)
            display = _to_short_display(email) if email else f"user_{user_id}"
    finally:
        conn.close()

    await broadcast_to_board(board_id, {
        "type": "PRESENCE_JOINED",
        "data": {
            "board_id": board_id,
            "user": {
                "user_id": user_id,
                "display": display or f"user_{user_id}",
                "email": email,
            },
        },
    })


async def _handle_leave_board(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    if board_id is None:
        await _send_error(ws, "VALIDATION_ERROR", "board_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id는 정수여야 합니다", req_id)
        return

    leave_room(board_id, ws)
    if ws in _ws_boards:
        _ws_boards[ws].discard(board_id)

    # PRESENCE_LEFT broadcast
    await broadcast_to_board(board_id, {
        "type": "PRESENCE_LEFT",
        "data": {"board_id": board_id, "user_id": user_id},
    })


def _ts_ms() -> int:
    return int(datetime.utcnow().timestamp() * 1000)


def _touch_and_get_board_version(cursor, board_id: int) -> int:
    cursor.execute("UPDATE boards SET updated_at = UTC_TIMESTAMP() WHERE id = %s", (board_id,))
    cursor.execute("SELECT UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s", (board_id,))
    row = cursor.fetchone()
    if row and row[0] is not None:
        return int(row[0])
    return int(time.time() * 1000)


def _get_board_version(cursor, board_id: int) -> int:
    cursor.execute("SELECT UNIX_TIMESTAMP(updated_at) * 1000 FROM boards WHERE id = %s", (board_id,))
    row = cursor.fetchone()
    if row and row[0] is not None:
        return int(row[0])
    return int(time.time() * 1000)


async def _handle_card_create(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    column_id = data.get("column_id")
    title = (data.get("title") or "").strip()
    if not board_id or not column_id or not title:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, column_id, title 필요", req_id)
        return

    try:
        board_id, column_id = int(board_id), int(column_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, column_id는 정수여야 합니다", req_id)
        return

    description = (data.get("description") or "").strip() or None
    priority = data.get("priority") or "medium"
    if priority not in ("low", "medium", "high"):
        priority = "medium"
    position = data.get("position")
    if position is None:
        position = 1000  # DB에서 계산할 예정

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "SELECT 1 FROM columns WHERE id = %s AND board_id = %s",
                (column_id, board_id),
            )
            if not cursor.fetchone():
                await _send_error(ws, "NOT_FOUND", "컬럼을 찾을 수 없습니다", req_id)
                return
            # 신규 카드는 컬럼 맨 위에 삽입
            cursor.execute(
                "SELECT MIN(position) FROM cards WHERE column_id = %s AND status = 'active'",
                (column_id,),
            )
            min_pos = cursor.fetchone()[0]
            position = (min_pos - 1000) if min_pos is not None else 0
            cursor.execute(
                """
                INSERT INTO cards (board_id, column_id, title, description, priority, status, position, created_by, updated_by)
                VALUES (%s, %s, %s, %s, %s, 'active', %s, %s, %s)
                """,
                (board_id, column_id, title, description, priority, position, user_id, user_id),
            )
            card_id = cursor.lastrowid
            board_version = _touch_and_get_board_version(cursor, board_id)
            conn.commit()

        payload = {
            "type": "CARD_CREATED",
            "data": {
                "board_id": board_id,
                "card": {
                    "id": card_id,
                    "column_id": column_id,
                    "title": title,
                    "description": description or "",
                    "priority": priority,
                    "status": "active",
                    "position": position,
                    "updated_at": _ts_ms(),
                },
                "board_version": board_version,
            },
        }
        if req_id:
            payload["req_id"] = req_id
        await broadcast_to_board(board_id, payload)
    finally:
        conn.close()


async def _handle_card_move(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    to_column_id = data.get("to_column_id")
    before_card_id = data.get("before_card_id")
    after_card_id = data.get("after_card_id")
    position = data.get("position")
    if not all([board_id, card_id, to_column_id is not None]):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id, to_column_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
        to_column_id = int(to_column_id)
        if before_card_id is not None:
            before_card_id = int(before_card_id)
        if after_card_id is not None:
            after_card_id = int(after_card_id)
        if position is not None:
            position = int(position)
    except (TypeError, ValueError):
        await _send_error(
            ws,
            "VALIDATION_ERROR",
            "board_id, card_id, to_column_id, before_card_id, after_card_id, position는 정수여야 합니다",
            req_id,
        )
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "SELECT 1 FROM cards WHERE id = %s AND board_id = %s AND status = 'active'",
                (card_id, board_id),
            )
            if not cursor.fetchone():
                await _send_error(ws, "NOT_FOUND", "카드를 찾을 수 없습니다", req_id)
                return
            cursor.execute(
                "SELECT 1 FROM columns WHERE id = %s AND board_id = %s",
                (to_column_id, board_id),
            )
            if not cursor.fetchone():
                await _send_error(ws, "VALIDATION_ERROR", "유효하지 않은 컬럼입니다", req_id)
                return

            # 상대 기준(before/after) 이동을 우선 처리한다.
            # (이전 position 기반 방식은 하위 호환으로만 유지)
            if before_card_id is not None:
                cursor.execute(
                    "SELECT 1 FROM cards WHERE id = %s AND board_id = %s AND column_id = %s AND status = 'active'",
                    (before_card_id, board_id, to_column_id),
                )
                if not cursor.fetchone():
                    await _send_error(ws, "VALIDATION_ERROR", "before_card_id가 유효하지 않습니다", req_id)
                    return
            if after_card_id is not None:
                cursor.execute(
                    "SELECT 1 FROM cards WHERE id = %s AND board_id = %s AND column_id = %s AND status = 'active'",
                    (after_card_id, board_id, to_column_id),
                )
                if not cursor.fetchone():
                    await _send_error(ws, "VALIDATION_ERROR", "after_card_id가 유효하지 않습니다", req_id)
                    return

            if before_card_id == card_id or after_card_id == card_id:
                await _send_error(ws, "VALIDATION_ERROR", "기준 카드에 자기 자신을 지정할 수 없습니다", req_id)
                return

            # 우선 대상 컬럼으로 이동시킨 뒤, 최종 순서를 계산한다.
            cursor.execute(
                "UPDATE cards SET column_id = %s, updated_by = %s WHERE id = %s",
                (to_column_id, user_id, card_id),
            )

            cursor.execute(
                """SELECT id FROM cards
                   WHERE column_id = %s AND board_id = %s AND status = 'active' AND id <> %s
                   ORDER BY position, id""",
                (to_column_id, board_id, card_id),
            )
            ordered_ids = [cid for (cid,) in cursor.fetchall()]

            # before_card_id: 이동 카드 "앞"에 있는 카드(이전 이웃)
            # after_card_id: 이동 카드 "뒤"에 있는 카드(다음 이웃)
            # 최종 배치는 [before, moved, after]가 되도록 계산한다.
            insert_index = len(ordered_ids)
            if after_card_id is not None:
                try:
                    insert_index = ordered_ids.index(after_card_id)
                except ValueError:
                    insert_index = len(ordered_ids)
            elif before_card_id is not None:
                try:
                    insert_index = ordered_ids.index(before_card_id) + 1
                except ValueError:
                    insert_index = len(ordered_ids)
            elif position is not None:
                # 하위 호환: position 기반 요청이면 기존 순서에서 삽입 위치를 근사 추정
                insert_index = len(ordered_ids)
                for i, cid in enumerate(ordered_ids):
                    cursor.execute("SELECT position FROM cards WHERE id = %s", (cid,))
                    row_pos = cursor.fetchone()
                    if row_pos and position < row_pos[0]:
                        insert_index = i
                        break

            ordered_ids.insert(insert_index, card_id)

            final_position = 0
            ordered_cards = []
            for i, cid in enumerate(ordered_ids):
                normalized_pos = i * 1000
                cursor.execute("UPDATE cards SET position = %s WHERE id = %s", (normalized_pos, cid))
                ordered_cards.append({"id": cid, "position": normalized_pos})
                if cid == card_id:
                    final_position = normalized_pos

            cursor.execute(
                "UPDATE cards SET updated_by = %s WHERE id = %s",
                (user_id, card_id),
            )
            board_version = _touch_and_get_board_version(cursor, board_id)
            conn.commit()

        payload = {
            "type": "CARD_MOVED",
            "data": {
                "board_id": board_id,
                "card_id": card_id,
                "column_id": to_column_id,
                "position": final_position,
                "column_cards": ordered_cards,
                "user_id": user_id,
                "updated_at": _ts_ms(),
                "board_version": board_version,
            },
        }
        if req_id:
            payload["req_id"] = req_id
        await broadcast_to_board(board_id, payload)
    finally:
        conn.close()


async def _handle_card_update(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    patch = data.get("patch") or {}
    if not board_id or not card_id or not isinstance(patch, dict):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id, patch 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "SELECT 1 FROM cards WHERE id = %s AND board_id = %s AND status = 'active'",
                (card_id, board_id),
            )
            if not cursor.fetchone():
                await _send_error(ws, "NOT_FOUND", "카드를 찾을 수 없습니다", req_id)
                return

            updates = []
            params = []
            if "title" in patch and patch["title"] is not None:
                updates.append("title = %s")
                params.append(str(patch["title"]).strip())
            if "description" in patch:
                updates.append("description = %s")
                params.append((patch["description"] or "").strip() or None)
            if "priority" in patch and patch["priority"] in ("low", "medium", "high"):
                updates.append("priority = %s")
                params.append(patch["priority"])
            if "assignee_id" in patch:
                updates.append("assignee_id = %s")
                params.append(patch["assignee_id"] if patch["assignee_id"] else None)
            if "due_date" in patch:
                updates.append("due_date = %s")
                params.append(patch["due_date"])
            if "status" in patch and patch["status"] in ("active", "done", "archived"):
                updates.append("status = %s")
                params.append(patch["status"])

            if not updates:
                cursor.execute(
                    "SELECT id, column_id, title, description, priority, status, position FROM cards WHERE id = %s",
                    (card_id,),
                )
                r = cursor.fetchone()
                payload = {
                    "type": "CARD_UPDATED",
                    "data": {
                        "board_id": board_id,
                        "card_id": card_id,
                        "patch": {"title": r[2], "description": r[3] or "", "priority": r[4], "status": r[5]},
                        "updated_at": _ts_ms(),
                        "board_version": _get_board_version(cursor, board_id),
                    },
                }
                if req_id:
                    payload["req_id"] = req_id
                await broadcast_to_board(board_id, payload)
                return

            updates.append("updated_by = %s")
            params.append(user_id)
            params.append(card_id)
            cursor.execute(
                f"UPDATE cards SET {', '.join(updates)} WHERE id = %s",
                params,
            )
            board_version = _touch_and_get_board_version(cursor, board_id)
            conn.commit()

        payload = {
            "type": "CARD_UPDATED",
            "data": {
                "board_id": board_id,
                "card_id": card_id,
                "patch": patch,
                "updated_at": _ts_ms(),
                "board_version": board_version,
            },
        }
        if req_id:
            payload["req_id"] = req_id
        await broadcast_to_board(board_id, payload)
    finally:
        conn.close()


async def _handle_card_archive(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    if not board_id or not card_id:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "UPDATE cards SET status = 'archived', updated_by = %s WHERE id = %s AND board_id = %s",
                (user_id, card_id, board_id),
            )
            if cursor.rowcount == 0:
                await _send_error(ws, "NOT_FOUND", "카드를 찾을 수 없습니다", req_id)
                return
            board_version = _touch_and_get_board_version(cursor, board_id)
            conn.commit()

        payload = {
            "type": "CARD_ARCHIVED",
            "data": {
                "board_id": board_id,
                "card_id": card_id,
                "status": "archived",
                "updated_at": _ts_ms(),
                "board_version": board_version,
            },
        }
        if req_id:
            payload["req_id"] = req_id
        await broadcast_to_board(board_id, payload)
    finally:
        conn.close()


async def _handle_card_restore(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    if not board_id or not card_id:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "UPDATE cards SET status = 'active', updated_by = %s WHERE id = %s AND board_id = %s",
                (user_id, card_id, board_id),
            )
            if cursor.rowcount == 0:
                await _send_error(ws, "NOT_FOUND", "카드를 찾을 수 없습니다", req_id)
                return
            board_version = _touch_and_get_board_version(cursor, board_id)
            conn.commit()

        payload = {
            "type": "CARD_RESTORED",
            "data": {
                "board_id": board_id,
                "card_id": card_id,
                "status": "active",
                "updated_at": _ts_ms(),
                "board_version": board_version,
            },
        }
        if req_id:
            payload["req_id"] = req_id
        await broadcast_to_board(board_id, payload)
    finally:
        conn.close()


async def _handle_lock_acquire(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    if not board_id or not card_id:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            if not _check_board_member(cursor, board_id, user_id):
                await _send_error(ws, "FORBIDDEN", "보드 접근 권한이 없습니다", req_id)
                return
            cursor.execute(
                "SELECT 1 FROM cards WHERE id = %s AND board_id = %s AND status = 'active'",
                (card_id, board_id),
            )
            if not cursor.fetchone():
                await _send_error(ws, "NOT_FOUND", "카드를 찾을 수 없습니다", req_id)
                return
            display = _get_user_display(cursor, user_id)
    finally:
        conn.close()

    ok, lock = acquire_lock(
        board_id=board_id,
        card_id=card_id,
        user_id=user_id,
        display=display,
    )
    if not ok:
        await _send_error(
            ws,
            "LOCKED",
            "다른 사용자가 편집 중입니다",
            req_id,
            detail={
                "card_id": card_id,
                "locked_by_user_id": lock["user_id"],
                "locked_by_display": lock["display"],
                "expires_at": lock["expires_at"],
            },
        )
        return

    payload = {
        "type": "CARD_LOCKED",
        "data": {
            "board_id": board_id,
            "card_id": card_id,
            "locked_by": {"user_id": lock["user_id"], "display": lock["display"]},
            "expires_at": lock["expires_at"],
        },
    }
    if req_id:
        payload["req_id"] = req_id
    await broadcast_to_board(board_id, payload)


async def _handle_lock_renew(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    if not board_id or not card_id:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    ok, lock = renew_lock(card_id=card_id, user_id=user_id)
    if not ok:
        await _send_error(ws, "LOCKED", "락 갱신 실패", req_id)
        return

    payload = {
        "type": "CARD_LOCKED",
        "data": {
            "board_id": board_id,
            "card_id": card_id,
            "locked_by": {"user_id": lock["user_id"], "display": lock["display"]},
            "expires_at": lock["expires_at"],
        },
    }
    if req_id:
        payload["req_id"] = req_id
    await broadcast_to_board(board_id, payload)


async def _handle_lock_release(ws: WebSocket, user_id: int, data: dict, req_id: str | None) -> None:
    board_id = data.get("board_id")
    card_id = data.get("card_id")
    if not board_id or not card_id:
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id 필요", req_id)
        return

    try:
        board_id = int(board_id)
        card_id = int(card_id)
    except (TypeError, ValueError):
        await _send_error(ws, "VALIDATION_ERROR", "board_id, card_id는 정수여야 합니다", req_id)
        return

    ok, _ = release_lock(card_id=card_id, user_id=user_id)
    if not ok:
        await _send_error(ws, "LOCKED", "락 해제 실패", req_id)
        return

    payload = {
        "type": "CARD_UNLOCKED",
        "data": {"board_id": board_id, "card_id": card_id},
    }
    if req_id:
        payload["req_id"] = req_id
    await broadcast_to_board(board_id, payload)


async def handle_ws_messages(websocket: WebSocket, user_id: int) -> None:
    """메시지 수신 루프"""
    setattr(websocket, "_user_id", user_id)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await _send_error(websocket, "VALIDATION_ERROR", "Invalid JSON")
                continue

            msg_type = msg.get("type")
            req_id = msg.get("req_id")
            data = msg.get("data") or {}

            if msg_type == "JOIN_BOARD":
                await _handle_join_board(websocket, user_id, data, req_id)
            elif msg_type == "LEAVE_BOARD":
                await _handle_leave_board(websocket, user_id, data, req_id)
            elif msg_type == "CARD_CREATE":
                await _handle_card_create(websocket, user_id, data, req_id)
            elif msg_type == "CARD_MOVE":
                await _handle_card_move(websocket, user_id, data, req_id)
            elif msg_type == "CARD_UPDATE":
                await _handle_card_update(websocket, user_id, data, req_id)
            elif msg_type == "CARD_ARCHIVE":
                await _handle_card_archive(websocket, user_id, data, req_id)
            elif msg_type == "CARD_RESTORE":
                await _handle_card_restore(websocket, user_id, data, req_id)
            elif msg_type == "LOCK_ACQUIRE":
                await _handle_lock_acquire(websocket, user_id, data, req_id)
            elif msg_type == "LOCK_RENEW":
                await _handle_lock_renew(websocket, user_id, data, req_id)
            elif msg_type == "LOCK_RELEASE":
                await _handle_lock_release(websocket, user_id, data, req_id)
            else:
                await _send_error(websocket, "VALIDATION_ERROR", f"Unknown type: {msg_type}", req_id)
    except Exception:
        pass
    finally:
        # 연결 종료 시 해당 사용자의 카드 락 해제
        released = release_locks_by_user(user_id)
        for lk in released:
            await broadcast_to_board(lk["board_id"], {
                "type": "CARD_UNLOCKED",
                "data": {"board_id": lk["board_id"], "card_id": lk["card_id"]},
            })

        # 연결 종료 시 모든 룸에서 제거
        if websocket in _ws_boards:
            for bid in list(_ws_boards[websocket]):
                leave_room(bid, websocket)
                # PRESENCE_LEFT broadcast
                await broadcast_to_board(bid, {
                    "type": "PRESENCE_LEFT",
                    "data": {"board_id": bid, "user_id": user_id},
                })
            del _ws_boards[websocket]
        leave_all_rooms(websocket)
