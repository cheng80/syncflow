"""
데이터베이스 연결 설정
HabitCell 습관 앱 MySQL 연결을 위한 설정
"""

import pymysql


# TODO: 실제 데이터베이스 설정으로 변경 필요
DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'root',
    'password': 'qwer1234',
    'database': 'habitcell_db',
    'charset': 'utf8mb4',
    'port': 3306
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
