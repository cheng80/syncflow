"""
WebSocket 연결 및 인증
wss://host/ws?token=<session_token>
"""

import json
import time
from fastapi import WebSocket, Query

from app.database.connection import connect_db
from app.utils.auth_deps import get_user_id_from_token


async def websocket_endpoint(
    websocket: WebSocket,
    token: str | None = Query(None, alias="token"),
):
    """
    WebSocket 엔드포인트
    - Query: token (session_token)
    - 검증 실패 시 연결 즉시 종료
    """
    if not token or not token.strip():
        await websocket.close(code=4001, reason="AUTH_REQUIRED")
        return

    try:
        user_id = get_user_id_from_token(token.strip())
    except Exception:
        await websocket.close(code=4002, reason="AUTH_INVALID")
        return

    await websocket.accept()

    # CONNECTED (선택)
    await websocket.send_json({
        "type": "CONNECTED",
        "data": {"server_time": int(time.time() * 1000)},
    })

    # handlers에서 메시지 루프 처리
    from app.ws.handlers import handle_ws_messages
    await handle_ws_messages(websocket, user_id)
