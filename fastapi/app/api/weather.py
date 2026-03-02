"""
Weather API - OpenWeatherMap API 직접 조회 (DB 저장 없음)
작성일: 2026-01-15
작성자: 김택권
수정일: 2026-01-21 - weather 테이블 제거 마이그레이션
"""

from fastapi import APIRouter, Query
from typing import Optional
from datetime import datetime
from ..utils.weather_service import WeatherService

router = APIRouter()


# ============================================
# OpenWeatherMap API에서 직접 날씨 데이터 가져오기 (DB 저장 없이)
# ============================================
@router.get("/direct")
async def fetch_weather_direct(
    lat: float = Query(..., description="위도 (필수)"),
    lon: float = Query(..., description="경도 (필수)"),
    start_date: Optional[str] = Query(None, description="시작 날짜 (YYYY-MM-DD), 없으면 오늘 포함 8일치 모두 반환")
):
    """
    OpenWeatherMap API에서 직접 날씨 데이터 가져오기 (DB 저장 없이)
    
    - lat, lon을 직접 받아서 OpenWeatherMap API 호출 (store 테이블 조회 없음)
    - start_date가 없으면: 오늘 포함 8일치 모두 반환
    - start_date가 있으면: 해당 날짜부터 남은 날짜만 반환 (최대 8일)
    - 날짜 검증: 과거 날짜 불가, 최대 8일까지만 가능
    
    예시:
        - start_date 없음: 오늘부터 8일치 모두 반환
        - start_date=오늘+3일: 오늘+3일부터 5일치만 반환 (총 8일 중 남은 5일)
    """
    try:
        # 날짜 파싱
        start_date_obj = None
        if start_date:
            try:
                start_date_obj = datetime.strptime(start_date, "%Y-%m-%d")
            except ValueError:
                return {
                    "result": "Error",
                    "errorMsg": f"날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 형식 필요): {start_date}"
                }
        
        # WeatherService를 사용하여 OpenWeatherMap API에서 직접 데이터 가져오기
        weather_service = WeatherService()
        forecast_list = weather_service.fetch_daily_forecast(
            lat=str(lat),
            lon=str(lon),
            start_date=start_date_obj
        )
        
        # 결과 포맷팅
        results = []
        for forecast in forecast_list:
            weather_datetime = forecast["weather_datetime"]
            if isinstance(weather_datetime, datetime):
                weather_datetime_str = weather_datetime.isoformat()
            else:
                weather_datetime_str = str(weather_datetime)
            
            results.append({
                'weather_datetime': weather_datetime_str,
                'weather_type': forecast["weather_type"],
                'weather_low': forecast["weather_low"],
                'weather_high': forecast["weather_high"],
                'icon_url': forecast["icon_url"]
            })
        
        return {"results": results}
        
    except ValueError as e:
        # 날짜 검증 오류
        return {
            "result": "Error",
            "errorMsg": str(e)
        }
    except Exception as e:
        import traceback
        error_msg = str(e)
        traceback.print_exc()
        return {
            "result": "Error",
            "errorMsg": error_msg,
            "traceback": traceback.format_exc()
        }


# ============================================
# OpenWeatherMap API에서 특정 날짜의 날씨 데이터만 가져오기 (DB 저장 없이, 하루치만)
# ============================================
@router.get("/direct/single")
async def fetch_weather_direct_single(
    lat: float = Query(..., description="위도 (필수)"),
    lon: float = Query(..., description="경도 (필수)"),
    target_date: Optional[str] = Query(None, description="조회할 날짜 (YYYY-MM-DD), 없으면 오늘 날짜")
):
    """
    OpenWeatherMap API에서 특정 날짜의 날씨 데이터만 가져오기 (DB 저장 없이, 하루치만)
    
    - lat, lon을 직접 받아서 OpenWeatherMap API 호출 (store 테이블 조회 없음)
    - target_date가 없으면 오늘 날씨만 반환
    - target_date가 있으면 해당 날짜의 날씨만 반환 (오늘부터 최대 8일까지만 가능)
    - 날짜 검증: 과거 날짜 불가, 최대 8일까지만 가능
    """
    try:
        # 날짜 파싱
        target_date_obj = None
        if target_date:
            try:
                target_date_obj = datetime.strptime(target_date, "%Y-%m-%d")
            except ValueError:
                return {
                    "result": "Error",
                    "errorMsg": f"날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 형식 필요): {target_date}"
                }
        
        # WeatherService를 사용하여 OpenWeatherMap API에서 특정 날짜의 날씨만 가져오기
        weather_service = WeatherService()
        forecast = weather_service.fetch_single_day_weather(
            lat=str(lat),
            lon=str(lon),
            target_date=target_date_obj
        )
        
        # 결과 포맷팅
        weather_datetime = forecast["weather_datetime"]
        if isinstance(weather_datetime, datetime):
            weather_datetime_str = weather_datetime.isoformat()
        else:
            weather_datetime_str = str(weather_datetime)
        
        result = {
            'weather_datetime': weather_datetime_str,
            'weather_type': forecast["weather_type"],
            'weather_low': forecast["weather_low"],
            'weather_high': forecast["weather_high"],
            'icon_url': forecast["icon_url"]
        }
        
        return {"result": result}
        
    except ValueError as e:
        # 날짜 검증 오류
        return {
            "result": "Error",
            "errorMsg": str(e)
        }
    except Exception as e:
        import traceback
        error_msg = str(e)
        traceback.print_exc()
        return {
            "result": "Error",
            "errorMsg": error_msg,
            "traceback": traceback.format_exc()
        }


# ============================================================
# 생성 이력
# ============================================================
# 작성일: 2026-01-15
# 작성자: 김택권
# 설명: Weather API - 날씨 데이터 CRUD 및 OpenWeatherMap API 연동
#
# ============================================================
# 수정 이력
# ============================================================
# 2026-01-15 김택권: 초기 생성
#   - 날씨 데이터 CRUD 엔드포인트 구현
#   - OpenWeatherMap API 연동 엔드포인트 구현
#
# 2026-01-18: OpenWeatherMap API 직접 조회 엔드포인트 추가
#   - GET /api/weather/direct 엔드포인트 추가 (DB 저장 없이 직접 조회)
#   - GET /api/weather/direct/single 엔드포인트 추가 (하루치만 조회)
#
# 2026-01-21 김택권: weather 테이블 제거 마이그레이션
#   - DB 관련 엔드포인트 전체 삭제 (CRUD, fetch-from-api)
#   - connect_db import 제거
#   - /direct, /direct/single 엔드포인트만 유지
#   - OpenWeatherMap API 직접 호출만 지원
