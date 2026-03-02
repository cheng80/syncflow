"""
OpenWeatherMap API 서비스
날씨 데이터를 직접 가져오는 서비스 (DB 저장 없음)
작성일: 2026-01-15
작성자: 김택권
수정일: 2026-01-21 - weather 테이블 제거 마이그레이션
"""

import os
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from dotenv import load_dotenv
from .weather_mapping import get_weather_type_korean, get_weather_icon_url  # noqa: E402

# ============================================
# OpenWeatherMap API 설정
# ============================================
# ⚠️ 주의: 이 API 키는 하드코딩되어 있습니다.
# - 다른 팀원들도 이 서비스를 바로 사용할 수 있도록 API 키를 코드에 포함했습니다.
# - 이 API 키는 수정하지 마세요. 모든 팀원이 공유해서 사용합니다.
# - 별도의 환경변수 설정 없이 WeatherService()를 바로 사용할 수 있습니다.
# - 하드코딩된 값이 없거나 빈 문자열이면 .env 파일에서 OPENWEATHER_API_KEY를 찾습니다.
# API 키: dbdd55a14dae1235d2dcb5d3499c03c2
HARDCODED_API_KEY = "dbdd55a14dae1235d2dcb5d3499c03c2"

# 하드코딩된 키가 없거나 빈 문자열이면 .env 파일에서 찾기
if not HARDCODED_API_KEY or HARDCODED_API_KEY.strip() == "":
    # .env 파일에서 환경변수 로드
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env')
    load_dotenv(dotenv_path=env_path)
    OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
else:
    OPENWEATHER_API_KEY = HARDCODED_API_KEY

OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/3.0/onecall"

# 기본 위치 설정 (서울)
DEFAULT_LAT = "37.5665"
DEFAULT_LON = "126.9780"


class WeatherService:
    """OpenWeatherMap API를 사용하여 날씨 데이터를 가져오는 서비스"""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        WeatherService 초기화
        
        Args:
            api_key: OpenWeatherMap API 키 (None이면 기본 하드코딩된 키 사용)
                     다른 API 키를 사용하고 싶을 때만 지정하세요.
                     
        사용 예시:
            # 기본 API 키 사용 (가장 일반적인 사용법)
            weather_service = WeatherService()
            
            # 다른 API 키 사용 (필요한 경우만)
            weather_service = WeatherService(api_key="your_api_key")
        """
        self.api_key = api_key or OPENWEATHER_API_KEY
        if not self.api_key:
            raise ValueError("OpenWeatherMap API 키가 설정되지 않았습니다. api_key 파라미터를 제공하세요.")
    
    def fetch_daily_forecast(
        self, 
        lat: str = DEFAULT_LAT, 
        lon: str = DEFAULT_LON,
        start_date: Optional[datetime] = None
    ) -> List[Dict]:
        """
        OpenWeatherMap OneCall API에서 일별 예보 가져오기 (DB 저장 없이)
        
        Args:
            lat: 위도 (기본값: 서울)
            lon: 경도 (기본값: 서울)
            start_date: 시작 날짜 (None이면 오늘 포함 8일치 모두 반환)
                       지정되면 해당 날짜부터 남은 날짜만 반환 (최대 8일)
            
        Returns:
            List[Dict]: 날씨 데이터 리스트
            - start_date가 None이면: 오늘 포함 8일치 모두 반환
            - start_date가 지정되면: 해당 날짜부터 남은 날짜만 반환
            각 Dict는 다음 키를 포함:
            - dt: Unix timestamp
            - weather_datetime: DATETIME 형식의 날짜 (00:00:00)
            - weather_type: 날씨 상태 (한글)
            - weather_type_en: 날씨 상태 (영문)
            - weather_low: 최저 온도
            - weather_high: 최고 온도
            - icon_code: 아이콘 코드
            - icon_url: 아이콘 URL
            
        Raises:
            requests.RequestException: API 요청 실패 시
            ValueError: API 응답이 유효하지 않을 때, 날짜 범위 초과 시
            
        예시:
            - start_date=None: 오늘부터 8일치 모두 반환
            - start_date=오늘+3일: 오늘+3일부터 5일치만 반환 (총 8일 중 남은 5일)
        """
        url = f"{OPENWEATHER_BASE_URL}?lat={lat}&lon={lon}&units=metric&exclude=minutely,alerts&appid={self.api_key}"
        
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if "daily" not in data or len(data["daily"]) == 0:
                raise ValueError("API 응답에 'daily' 데이터가 없습니다.")
            
            # 날짜 검증
            today = datetime.now().date()
            max_date = today + timedelta(days=7)  # 오늘 포함 8일 = 오늘 + 7일
            
            start_date_only = None
            if start_date:
                # start_date가 datetime이면 date만 추출
                if isinstance(start_date, datetime):
                    start_date_only = start_date.date()
                elif isinstance(start_date, str):
                    # 문자열인 경우 파싱
                    try:
                        start_date_only = datetime.strptime(start_date, "%Y-%m-%d").date()
                    except ValueError:
                        raise ValueError(f"날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 형식 필요): {start_date}")
                else:
                    start_date_only = start_date
                
                if start_date_only < today:
                    raise ValueError("과거 날짜의 실시간 예보는 조회할 수 없습니다.")
                
                if start_date_only > max_date:
                    raise ValueError(f"예보는 오늘부터 최대 8일까지만 조회 가능합니다. (요청한 날짜: {start_date_only})")
            
            result = []
            
            for daily_item in data["daily"]:
                # Unix timestamp를 datetime으로 변환
                dt = datetime.fromtimestamp(daily_item["dt"])
                # 날짜의 시작 시간 (00:00:00)으로 설정
                weather_datetime = dt.replace(hour=0, minute=0, second=0, microsecond=0)
                weather_date = weather_datetime.date()
                
                # 날짜 필터링
                if start_date_only:
                    # start_date부터만 포함 (해당 날짜부터 남은 날짜만)
                    if weather_date < start_date_only:
                        continue
                
                # 날씨 정보 추출
                weather_info = daily_item["weather"][0] if daily_item.get("weather") else {}
                weather_main = weather_info.get("main", "Clear")
                icon_code = weather_info.get("icon", "01d")
                
                # 온도 정보 추출
                temp = daily_item.get("temp", {})
                
                # OpenWeatherMap OneCall API 3.0 구조 확인
                # temp 객체에는 min, max, day, night, eve, morn 필드가 있음
                weather_low = temp.get("min", None)
                weather_high = temp.get("max", None)
                
                # 값이 없거나 None인 경우 처리
                if weather_low is None:
                    print(f"⚠️  Warning: temp.min not found in API response. temp keys: {list(temp.keys())}")
                    weather_low = 0.0
                if weather_high is None:
                    print(f"⚠️  Warning: temp.max not found in API response. temp keys: {list(temp.keys())}")
                    weather_high = 0.0
                
                # 온도 값 검증 (한국 기준: -30~50도 범위)
                weather_low = float(weather_low)
                weather_high = float(weather_high)
                
                if weather_low < -30 or weather_low > 50:
                    print(f"⚠️  Warning: weather_low ({weather_low}°C) is out of normal range for Korea")
                if weather_high < -30 or weather_high > 50:
                    print(f"⚠️  Warning: weather_high ({weather_high}°C) is out of normal range for Korea")
                if weather_low > weather_high:
                    print(f"⚠️  Warning: weather_low ({weather_low}°C) is greater than weather_high ({weather_high}°C)")
                    # 최저/최고 온도 교정
                    weather_low, weather_high = weather_high, weather_low
                
                result.append({
                    "dt": daily_item["dt"],
                    "weather_datetime": weather_datetime,
                    "weather_type": get_weather_type_korean(weather_main),
                    "weather_type_en": weather_main,
                    "weather_low": weather_low,
                    "weather_high": weather_high,
                    "icon_code": icon_code,
                    "icon_url": get_weather_icon_url(icon_code)
                })
            
            return result
            
        except requests.RequestException as e:
            raise requests.RequestException(f"OpenWeatherMap API 요청 실패: {str(e)}") from e
        except (KeyError, ValueError, TypeError) as e:
            raise ValueError(f"API 응답 파싱 실패: {str(e)}") from e
    
    def fetch_single_day_weather(
        self,
        lat: str = DEFAULT_LAT,
        lon: str = DEFAULT_LON,
        target_date: Optional[datetime] = None
    ) -> Dict:
        """
        OpenWeatherMap OneCall API에서 특정 날짜의 날씨 데이터만 가져오기 (DB 저장 없이, 하루치만)
        
        Args:
            lat: 위도 (기본값: 서울)
            lon: 경도 (기본값: 서울)
            target_date: 조회할 날짜 (None이면 오늘 날짜, 최대 8일까지만 가능)
            
        Returns:
            Dict: 날씨 데이터 (하루치)
            다음 키를 포함:
            - dt: Unix timestamp
            - weather_datetime: DATETIME 형식의 날짜 (00:00:00)
            - weather_type: 날씨 상태 (한글)
            - weather_type_en: 날씨 상태 (영문)
            - weather_low: 최저 온도
            - weather_high: 최고 온도
            - icon_code: 아이콘 코드
            - icon_url: 아이콘 URL
            
        Raises:
            requests.RequestException: API 요청 실패 시
            ValueError: API 응답이 유효하지 않을 때, 날짜 범위 초과 시, 해당 날짜 데이터가 없을 때
        """
        # 날짜 파싱
        target_date_only = None
        if target_date:
            if isinstance(target_date, datetime):
                target_date_only = target_date.date()
            elif isinstance(target_date, str):
                try:
                    target_date_only = datetime.strptime(target_date, "%Y-%m-%d").date()
                except ValueError:
                    raise ValueError(f"날짜 형식이 올바르지 않습니다. (YYYY-MM-DD 형식 필요): {target_date}")
            else:
                target_date_only = target_date
        else:
            # None이면 오늘 날짜
            target_date_only = datetime.now().date()
        
        # fetch_daily_forecast를 사용하여 해당 날짜부터 가져오기 (하루만 필요)
        forecast_list = self.fetch_daily_forecast(
            lat=lat,
            lon=lon,
            start_date=target_date_only
        )
        
        if not forecast_list or len(forecast_list) == 0:
            raise ValueError(f"해당 날짜({target_date_only})의 날씨 데이터를 찾을 수 없습니다.")
        
        # 첫 번째 항목만 반환 (하루치만)
        return forecast_list[0]


# ============================================================
# 생성 이력
# ============================================================
# 작성일: 2026-01-15
# 작성자: 김택권
# 설명: OpenWeatherMap API 서비스 - 날씨 데이터를 가져와서 데이터베이스에 저장하는 서비스
#
# ============================================================
# 수정 이력
# ============================================================
# 2026-01-15 김택권: 초기 생성
#   - OpenWeatherMap OneCall API 연동 구현
#   - 일별 날씨 데이터 가져오기 기능 (fetch_daily_weather)
#   - 날씨 데이터를 데이터베이스에 저장하는 기능 (save_weather_to_db)
#
# 2026-01-18: OpenWeatherMap API 직접 조회 기능 추가
#   - fetch_daily_forecast 메서드 추가 (8일치 예보)
#   - DB 저장 없이 OpenWeatherMap API에서 직접 데이터 가져오기
#
# 2026-01-21 김택권: weather 테이블 제거 마이그레이션
#   - connect_db import 제거
#   - save_weather_to_db() 메서드 삭제
#   - fetch_daily_forecast(), fetch_single_day_weather()만 유지
#   - OpenWeatherMap API 직접 호출만 지원
