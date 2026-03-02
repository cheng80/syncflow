"""
Habit App FastAPI 백엔드
습관 앱 백업/복구 API (Local-first + Snapshot Backup)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# .env 파일에서 환경변수 로드
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
load_dotenv(dotenv_path=env_path)

app = FastAPI(
    title="Habit App API",
    description="습관 앱 백업/복구를 위한 REST API",
    version="1.0.0"
)

# CORS 설정 (Flutter 앱과 통신을 위해 필요)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 환경용, 프로덕션에서는 특정 도메인으로 제한
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# 라우터 등록
# ============================================
from app.api import backups, recovery
app.include_router(backups.router, prefix="/v1/backups", tags=["backups"])
app.include_router(recovery.router, prefix="/v1/recovery", tags=["recovery"])

@app.get("/")
async def root():
    """루트 엔드포인트 - API 정보 반환"""
    return {
        "message": "Habit App API",
        "status": "running",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "docs": "/docs",
            "redoc": "/redoc"
        }
    }


@app.get("/health")
async def health_check():
    """헬스 체크 엔드포인트"""
    # 데이터베이스 연결이 필요할 때 주석 해제
    # try:
    #     conn = connect_db()
    #     conn.close()
    #     return {"status": "healthy", "database": "connected"}
    # except Exception as e:
    #     return {"status": "unhealthy", "error": str(e)}
    
    return {
        "status": "healthy",
        "message": "API is running"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)