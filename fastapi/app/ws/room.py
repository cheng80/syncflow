"""
보드 룸 관리 및 브로드캐스트
룸 키: board:<board_id>
"""

from collections import defaultdict
from typing import Any

from fastapi import WebSocket

# board_id -> set of WebSocket connections
_rooms: dict[int, set[WebSocket]] = defaultdict(set)


def room_key(board_id: int) -> str:
    return f"board:{board_id}"


def join_room(board_id: int, ws: WebSocket) -> None:
    _rooms[board_id].add(ws)


def leave_room(board_id: int, ws: WebSocket) -> None:
    _rooms[board_id].discard(ws)
    if not _rooms[board_id]:
        del _rooms[board_id]


def leave_all_rooms(ws: WebSocket) -> None:
    """연결 종료 시 해당 ws가 속한 모든 룸에서 제거"""
    to_remove = []
    for board_id, conns in _rooms.items():
        if ws in conns:
            conns.discard(ws)
            if not conns:
                to_remove.append(board_id)
    for bid in to_remove:
        del _rooms[bid]


def get_room_members(board_id: int) -> set[WebSocket]:
    return _rooms.get(board_id, set()).copy()


async def broadcast_to_board(board_id: int, message: dict[str, Any]) -> None:
    """보드 룸에 브로드캐스트 (발신자 제외)"""
    for ws in list(_rooms.get(board_id, set())):
        try:
            await ws.send_json(message)
        except Exception:
            pass  # 연결 끊김 등 무시
