"""
데이터베이스 연결 설정
SyncFlow 협업 보드 앱 MySQL 접속 (이 모듈 사용)
"""

import os
import pymysql

# .env에서 DB 설정 로드 (main.py에서 load_dotenv 호출됨)
DB_CONFIG = {
    'host': os.getenv('DB_HOST', '127.0.0.1'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': os.getenv('DB_NAME', 'syncflow_db'),
    'charset': 'utf8mb4',
    'port': int(os.getenv('DB_PORT', '3306'))
}


def connect_db():
    """
    데이터베이스 연결
    
    Returns:
        pymysql.Connection: 데이터베이스 연결 객체
        
    Raises:
        pymysql.Error: 데이터베이스 연결 실패 시
    """
    try:
        conn = pymysql.connect(**DB_CONFIG)
        return conn
    except pymysql.Error as e:
        raise pymysql.Error(f"Database connection failed: {str(e)}") from e
