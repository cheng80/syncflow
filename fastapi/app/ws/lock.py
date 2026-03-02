"""
카드 Soft Lock 메모리 저장소 (MVP, 단일 인스턴스)
"""

import time


LOCK_TTL_SEC = 30

# card_id -> lock info
_locks: dict[int, dict] = {}


def _now_ms() -> int:
    return int(time.time() * 1000)


def _purge_expired() -> None:
    now = _now_ms()
    expired = [cid for cid, v in _locks.items() if v["expires_at"] <= now]
    for cid in expired:
        del _locks[cid]


def get_lock(card_id: int) -> dict | None:
    _purge_expired()
    return _locks.get(card_id)


def acquire_lock(*, board_id: int, card_id: int, user_id: int, display: str) -> tuple[bool, dict]:
    _purge_expired()
    cur = _locks.get(card_id)
    now = _now_ms()
    expires_at = now + LOCK_TTL_SEC * 1000

    if cur and cur["user_id"] != user_id:
        return False, cur

    lock = {
        "board_id": board_id,
        "card_id": card_id,
        "user_id": user_id,
        "display": display,
        "expires_at": expires_at,
    }
    _locks[card_id] = lock
    return True, lock


def renew_lock(*, card_id: int, user_id: int) -> tuple[bool, dict | None]:
    _purge_expired()
    cur = _locks.get(card_id)
    if not cur:
        return False, None
    if cur["user_id"] != user_id:
        return False, cur
    cur["expires_at"] = _now_ms() + LOCK_TTL_SEC * 1000
    return True, cur


def release_lock(*, card_id: int, user_id: int) -> tuple[bool, dict | None]:
    _purge_expired()
    cur = _locks.get(card_id)
    if not cur:
        return False, None
    if cur["user_id"] != user_id:
        return False, cur
    del _locks[card_id]
    return True, cur


def release_locks_by_user(user_id: int) -> list[dict]:
    _purge_expired()
    released = []
    for card_id, info in list(_locks.items()):
        if info["user_id"] == user_id:
            released.append(info)
            del _locks[card_id]
    return released

