#!/usr/bin/env python3
"""
init_schema.sql 실행 스크립트
DB 접속 후 스키마 생성
"""

import os
import sys

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

import pymysql

def main():
    schema_path = os.path.join(os.path.dirname(__file__), '..', 'mysql', 'init_schema.sql')
    with open(schema_path, 'r', encoding='utf-8') as f:
        sql_content = f.read()

    db_name = os.getenv('DB_NAME', 'syncflow_db')

    # 1단계: DB 없이 연결 → CREATE DATABASE 실행
    conn = pymysql.connect(
        host=os.getenv('DB_HOST', '127.0.0.1'),
        user=os.getenv('DB_USER', 'root'),
        password=os.getenv('DB_PASSWORD', ''),
        charset='utf8mb4',
        port=int(os.getenv('DB_PORT', '3306'))
    )

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                f"CREATE DATABASE IF NOT EXISTS {db_name} "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
            conn.commit()
            print(f"OK: CREATE DATABASE {db_name}")
        conn.close()

        # 2단계: syncflow_db로 연결 후 테이블 생성
        conn = pymysql.connect(
            host=os.getenv('DB_HOST', '127.0.0.1'),
            user=os.getenv('DB_USER', 'root'),
            password=os.getenv('DB_PASSWORD', ''),
            database=db_name,
            charset='utf8mb4',
            port=int(os.getenv('DB_PORT', '3306'))
        )

        # CREATE DATABASE, USE 제외한 나머지 문장만 실행
        statements = [s.strip() for s in sql_content.split(';') if s.strip()]
        def clean_stmt(stmt):
            lines = [l for l in stmt.split('\n') if l.strip() and not l.strip().startswith('--')]
            return '\n'.join(lines).strip()

        with conn.cursor() as cursor:
            for stmt in statements:
                stmt = clean_stmt(stmt)
                if not stmt or stmt.upper().startswith('CREATE DATABASE') or stmt.upper().startswith('USE '):
                    continue
                try:
                    cursor.execute(stmt)
                    conn.commit()
                    first_words = ' '.join(stmt.split()[:4])
                    print(f"OK: {first_words}...")
                except Exception as e:
                    print(f"ERR: {stmt[:80]}...")
                    print(f"  -> {e}")
                    raise

        print(f"\n{db_name} 스키마 생성 완료.")
    finally:
        conn.close()


if __name__ == '__main__':
    main()
