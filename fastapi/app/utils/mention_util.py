import re
from typing import Iterable

import pymysql


# @username 또는 @user@domain.com 형식 (이메일 내부 @는 하나의 멘션으로 유지)
_MENTION_TOKEN_RE = re.compile(
    r"@([^\s@,;:(){}\[\]<>]+@[^\s@,;:(){}\[\]<>]+|[^\s@,;:(){}\[\]<>]+)"
)


def extract_mention_tokens(*texts: str | None) -> list[str]:
    tokens: list[str] = []
    seen: set[str] = set()
    for text in texts:
        if not text:
            continue
        for raw in _MENTION_TOKEN_RE.findall(text):
            token = raw.strip().lower()
            if not token or token in seen:
                continue
            seen.add(token)
            tokens.append(token)
    return tokens


def resolve_mentioned_user_ids(cursor, board_id: int, *texts: str | None) -> list[int]:
    tokens = extract_mention_tokens(*texts)
    if not tokens:
        return []

    cursor.execute(
        """
        SELECT bm.user_id, LOWER(u.email) AS email
        FROM board_members bm
        INNER JOIN users u ON u.id = bm.user_id
        WHERE bm.board_id = %s
        """,
        (board_id,),
    )
    rows = cursor.fetchall()
    if not rows:
        return []

    email_to_id: dict[str, int] = {}
    local_to_ids: dict[str, list[int]] = {}
    for uid, email in rows:
        if not email:
            continue
        email_to_id[email] = int(uid)
        local = email.split("@", 1)[0]
        local_to_ids.setdefault(local, []).append(int(uid))

    mentioned: list[int] = []
    seen_ids: set[int] = set()

    for token in tokens:
        uid: int | None = None
        if "@" in token:
            uid = email_to_id.get(token)
        else:
            local_matches = local_to_ids.get(token, [])
            if len(local_matches) == 1:
                uid = local_matches[0]
        if uid is None or uid in seen_ids:
            continue
        seen_ids.add(uid)
        mentioned.append(uid)

    return mentioned


def sync_card_mentions(
    cursor,
    board_id: int,
    card_id: int,
    *texts: str | None,
) -> list[int]:
    mentioned_user_ids = resolve_mentioned_user_ids(cursor, board_id, *texts)

    try:
        if not mentioned_user_ids:
            cursor.execute("DELETE FROM card_mentions WHERE card_id = %s", (card_id,))
            return []

        placeholders = ", ".join(["%s"] * len(mentioned_user_ids))
        cursor.execute(
            f"DELETE FROM card_mentions WHERE card_id = %s AND mentioned_user_id NOT IN ({placeholders})",
            (card_id, *mentioned_user_ids),
        )

        values = [(board_id, card_id, uid, None) for uid in mentioned_user_ids]
        cursor.executemany(
            """
            INSERT INTO card_mentions (board_id, card_id, mentioned_user_id, source_token)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              source_token = VALUES(source_token),
              updated_at = UTC_TIMESTAMP()
            """,
            values,
        )
    except pymysql.err.ProgrammingError as e:
        # 호환성: 일부 환경에서 card_mentions 테이블이 아직 없을 수 있다.
        if e.args and e.args[0] == 1146:
            return mentioned_user_ids
        raise

    return mentioned_user_ids


def get_card_mentioned_user_ids(
    cursor,
    card_id: int,
    *,
    fallback_board_id: int | None = None,
    fallback_texts: Iterable[str | None] = (),
) -> list[int]:
    try:
        cursor.execute(
            "SELECT mentioned_user_id FROM card_mentions WHERE card_id = %s ORDER BY id",
            (card_id,),
        )
        ids = [int(r[0]) for r in cursor.fetchall()]
        if ids:
            return ids
    except pymysql.err.ProgrammingError as e:
        if not (e.args and e.args[0] == 1146):
            raise

    if fallback_board_id is None:
        return []
    return resolve_mentioned_user_ids(cursor, fallback_board_id, *list(fallback_texts))


def get_mentions_map_by_card_ids(cursor, card_ids: list[int]) -> dict[int, list[int]]:
    if not card_ids:
        return {}

    placeholders = ", ".join(["%s"] * len(card_ids))
    try:
        cursor.execute(
            f"""
            SELECT card_id, mentioned_user_id
            FROM card_mentions
            WHERE card_id IN ({placeholders})
            ORDER BY id
            """,
            tuple(card_ids),
        )
    except pymysql.err.ProgrammingError as e:
        if e.args and e.args[0] == 1146:
            return {}
        raise

    result: dict[int, list[int]] = {}
    for card_id, user_id in cursor.fetchall():
        cid = int(card_id)
        result.setdefault(cid, []).append(int(user_id))
    return result
