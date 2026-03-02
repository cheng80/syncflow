"""
SyncFlow FastAPI 백엔드
실시간 경량 협업 칸반 보드 API
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# .env 파일에서 환경변수 로드
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
load_dotenv(dotenv_path=env_path)

app = FastAPI(
    title="SyncFlow API",
    description="실시간 경량 협업 칸반 보드 REST API",
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
from app.api import auth, boards, cards

app.include_router(auth.router, prefix="/v1/auth", tags=["auth"])
app.include_router(boards.router, prefix="/v1/boards", tags=["boards"])
app.include_router(cards.router, prefix="/v1/cards", tags=["cards"])

# WebSocket
from app.ws.connection import websocket_endpoint
app.websocket("/ws")(websocket_endpoint)


@app.get("/")
async def root():
    """루트 엔드포인트 - API 정보 반환"""
    return {
        "message": "SyncFlow API",
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
    return {
        "status": "healthy",
        "message": "API is running"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
