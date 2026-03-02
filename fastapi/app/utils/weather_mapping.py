"""
날씨 상태 매핑 테이블
OpenWeatherMap API의 weather.main 값을 한글로 변환하는 매핑 테이블
작성일: 2026-01-15
작성자: 김택권
"""

# OpenWeatherMap weather.main → 한글 매핑
WEATHER_TYPE_MAPPING = {
    "Clear": "맑음",
    "Clouds": "흐림",
    "Rain": "비",
    "Drizzle": "이슬비",
    "Thunderstorm": "천둥번개",
    "Snow": "눈",
    "Mist": "안개",
    "Fog": "짙은 안개",
    "Haze": "연무",
    "Dust": "먼지",
    "Sand": "모래",
    "Ash": "화산재",
    "Squall": "돌풍",
    "Tornado": "토네이도"
}

# OpenWeatherMap weather.main → 아이콘 코드 매핑 (기본값)
# 실제 아이콘 코드는 API 응답의 weather[].icon을 사용하지만,
# 매핑이 실패할 경우를 대비한 기본값
WEATHER_ICON_MAPPING = {
    "Clear": "01d",      # 맑음 (낮)
    "Clouds": "02d",     # 흐림
    "Rain": "10d",       # 비
    "Drizzle": "09d",    # 이슬비
    "Thunderstorm": "11d",  # 천둥번개
    "Snow": "13d",       # 눈
    "Mist": "50d",       # 안개
    "Fog": "50d",        # 짙은 안개
    "Haze": "50d",       # 연무
    "Dust": "50d",       # 먼지
    "Sand": "50d",       # 모래
    "Ash": "50d",        # 화산재
    "Squall": "11d",     # 돌풍
    "Tornado": "11d"     # 토네이도
}


def get_weather_type_korean(weather_main: str) -> str:
    """
    OpenWeatherMap weather.main 값을 한글로 변환
    
    Args:
        weather_main: OpenWeatherMap API의 weather.main 값 (예: "Clear", "Rain")
        
    Returns:
        str: 한글 날씨 상태 (예: "맑음", "비")
        매핑되지 않은 경우 원본 값 반환
    """
    return WEATHER_TYPE_MAPPING.get(weather_main, weather_main)


def get_weather_icon_url(icon_code: str, size: str = "2x") -> str:
    """
    OpenWeatherMap 아이콘 URL 생성
    
    Args:
        icon_code: OpenWeatherMap API의 weather.icon 값 (예: "01d", "10n")
        size: 아이콘 크기 ("1x", "2x", "4x"), 기본값 "2x"
        
    Returns:
        str: OpenWeatherMap 아이콘 URL
        예: "http://openweathermap.org/img/wn/01d@2x.png"
    """
    base_url = "http://openweathermap.org/img/wn"
    return f"{base_url}/{icon_code}@{size}.png"


def get_default_icon_code(weather_main: str) -> str:
    """
    weather.main 값으로부터 기본 아이콘 코드 반환
    (API 응답에 icon이 없을 경우 사용)
    
    Args:
        weather_main: OpenWeatherMap API의 weather.main 값 또는 한글 날씨 상태
        
    Returns:
        str: 기본 아이콘 코드
    """
    # 한글 날씨 상태인 경우 영문으로 역매핑
    korean_to_english = {v: k for k, v in WEATHER_TYPE_MAPPING.items()}
    weather_main_en = korean_to_english.get(weather_main, weather_main)
    return WEATHER_ICON_MAPPING.get(weather_main_en, "01d")
