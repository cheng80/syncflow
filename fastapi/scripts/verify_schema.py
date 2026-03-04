#!/usr/bin/env python3
"""
syncflow_db 테이블·컬럼 유효성 검증
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

from app.database.connection import connect_db

# ERD v1.1 기준 기대 스키마
EXPECTED = {
    'users': ['id', 'email', 'email_verified_at', 'created_at', 'updated_at'],
    'email_verifications': ['id', 'email', 'code_hash', 'expires_at', 'attempt_count', 'created_at'],
    'sessions': ['id', 'user_id', 'session_token', 'expires_at', 'revoked', 'created_at'],
    'boards': ['id', 'owner_id', 'title', 'template_json', 'created_at', 'updated_at'],
    'board_members': ['id', 'board_id', 'user_id', 'role', 'joined_at'],
    'columns': ['id', 'board_id', 'title', 'position', 'is_done', 'created_at', 'updated_at'],
    'cards': ['id', 'board_id', 'column_id', 'title', 'description', 'priority', 'assignee_id', 'due_date',
              'status', 'position', 'owner_lock', 'owner_lock_by', 'owner_lock_at',
              'updated_at', 'updated_by', 'created_at', 'created_by'],
    'card_mentions': ['id', 'board_id', 'card_id', 'mentioned_user_id', 'source_token', 'created_at', 'updated_at'],
    'board_invites': ['id', 'board_id', 'code', 'created_by', 'expires_at', 'max_uses', 'used_count', 'revoked', 'created_at'],
}


def main():
    conn = connect_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            tables = [row[0] for row in cursor.fetchall()]

        print("=" * 60)
        print("syncflow_db 스키마 유효성 검증")
        print("=" * 60)

        all_ok = True
        for table in EXPECTED:
            if table not in tables:
                print(f"\n❌ 테이블 없음: {table}")
                all_ok = False
                continue

            with conn.cursor() as cursor:
                cursor.execute(f"DESCRIBE `{table}`")
                cols = [row[0] for row in cursor.fetchall()]

            expected_cols = set(EXPECTED[table])
            actual_cols = set(cols)
            missing = expected_cols - actual_cols
            extra = actual_cols - expected_cols

            if missing or extra:
                print(f"\n❌ {table}:")
                if missing:
                    print(f"   누락 컬럼: {sorted(missing)}")
                if extra:
                    print(f"   추가 컬럼: {sorted(extra)}")
                all_ok = False
            else:
                print(f"\n✅ {table}: {len(cols)}개 컬럼")

        # 테이블 목록에 없는 기대 테이블
        for t in EXPECTED:
            if t not in tables:
                all_ok = False
        # DB에만 있는 테이블 (예상 외)
        extra_tables = set(tables) - set(EXPECTED)
        if extra_tables:
            print(f"\n⚠️  예상 외 테이블: {sorted(extra_tables)}")

        print("\n" + "=" * 60)
        print("✅ 유효성 검증 완료" if all_ok else "❌ 유효성 검증 실패")
        print("=" * 60)
        return 0 if all_ok else 1

    finally:
        conn.close()


if __name__ == '__main__':
    sys.exit(main())
