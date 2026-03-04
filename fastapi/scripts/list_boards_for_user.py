#!/usr/bin/env python3
"""
cheng80@gmail.com 사용자의 보드 목록 조회
- DB 직접 조회 (users, board_members, boards)
- API 호출 (선택, session_token 필요)
"""

import os
import sys

# fastapi 앱 루트를 path에 추가 (.env 로드용)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

import pymysql

DB_CONFIG = {
    'host': os.getenv('DB_HOST', '127.0.0.1'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': os.getenv('DB_NAME', 'syncflow_db'),
    'charset': 'utf8mb4',
    'port': int(os.getenv('DB_PORT', '3306')),
}


def main():
    email = 'cheng80@gmail.com'
    print(f"=== {email} 보드 목록 조회 ===\n")

    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor() as cursor:
            # 1. 사용자 조회
            cursor.execute("SELECT id, email, created_at FROM users WHERE email = %s", (email,))
            user_row = cursor.fetchone()
            if not user_row:
                print(f"[결과] users 테이블에 '{email}' 사용자가 없습니다.")
                print("\n[전체 users 목록]")
                cursor.execute("SELECT id, email FROM users ORDER BY id")
                for r in cursor.fetchall():
                    print(f"  - id={r[0]}, email={r[1]}")
                return

            user_id, user_email, created_at = user_row
            print(f"[사용자] id={user_id}, email={user_email}, created_at={created_at}")

            # 2. 보드 목록 (board_members 기준 - API와 동일 쿼리)
            cursor.execute(
                """
                SELECT b.id, b.title, b.owner_id, b.created_at, bm.role
                FROM boards b
                INNER JOIN board_members bm ON b.id = bm.board_id
                WHERE bm.user_id = %s
                ORDER BY b.updated_at DESC
                """,
                (user_id,),
            )
            rows = cursor.fetchall()

            print(f"\n[보드 목록] 총 {len(rows)}개 (board_members 기준)")
            if not rows:
                print("  (없음)")
            else:
                for r in rows:
                    bid, title, owner_id, created, role = r
                    owner_mark = " (owner)" if owner_id == user_id else ""
                    print(f"  - id={bid}, title={title!r}, owner_id={owner_id}, role={role}{owner_mark}")

            # 3. 전체 boards 테이블 (디버깅용)
            cursor.execute("SELECT COUNT(*) FROM boards")
            total_boards = cursor.fetchone()[0]
            print(f"\n[전체 boards 테이블] 총 {total_boards}개")
            if total_boards > 0 and len(rows) < total_boards:
                cursor.execute(
                    "SELECT b.id, b.title, b.owner_id FROM boards b ORDER BY b.id"
                )
                for r in cursor.fetchall():
                    bid, title, owner_id = r
                    # 이 사용자가 멤버인지 확인
                    cursor.execute(
                        "SELECT 1 FROM board_members WHERE board_id = %s AND user_id = %s",
                        (bid, user_id),
                    )
                    is_member = cursor.fetchone() is not None
                    status = "멤버 O" if is_member else "멤버 X"
                    print(f"  - id={bid}, title={title!r}, owner_id={owner_id} [{status}]")

            # 4. 유효한 세션 존재 여부
            cursor.execute(
                """
                SELECT session_token, expires_at, revoked
                FROM sessions
                WHERE user_id = %s AND revoked = FALSE AND expires_at > UTC_TIMESTAMP()
                ORDER BY created_at DESC
                LIMIT 3
                """,
                (user_id,),
            )
            sessions = cursor.fetchall()
            print(f"\n[유효 세션] {len(sessions)}개")
            for s in sessions:
                token, exp, rev = s
                print(f"  - token={token[:8]}..., expires_at={exp}, revoked={rev}")

    finally:
        conn.close()


if __name__ == '__main__':
    main()
