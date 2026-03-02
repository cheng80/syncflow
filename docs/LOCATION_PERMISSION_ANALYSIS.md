# 위치 권한 사용처 분석

## 결론: **이 앱은 위치(GPS) 기능을 사용하지 않습니다.**

위치 권한 요청이 보인다면, 아래 원인 후보를 확인해 보세요.

---

## 1. 코드 내 사용처 검색 결과

### ❌ 위치 기능 미사용

| 파일/패키지 | 검색 키워드 | 결과 |
|-------------|-------------|------|
| `lib/` | `location`, `Location`, `geolocator` | **사용처 없음** |
| `permission_handler` | `Permission.location` | **사용처 없음** (알림만 사용) |
| `Info.plist` | `NSLocation*` | **키 없음** |

### ⚠️ 혼동 가능한 코드: `tz.getLocation('Asia/Seoul')`

```dart
// lib/service/notification_service.dart:35
tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
```

- **역할**: 타임존(시간대) 설정
- **의미**: "Asia/Seoul"은 IANA 타임존 ID (서울 시간대)
- **GPS 사용 여부**: 사용하지 않음 (위치 권한과 무관)

---

## 2. 권한 관련 사용처

| 패키지 | 사용 권한 | 용도 |
|--------|-----------|------|
| `permission_handler` | `Permission.notification` | 알림 권한 상태 확인, 설정 화면 열기 |
| `flutter_local_notifications` | 알림(alert/badge/sound) | 마감일 알람 등록 |

---

## 3. 위치 권한이 보일 수 있는 원인

### (1) permission_handler Podfile 설정

`permission_handler`는 Podfile에서 사용할 권한을 지정해야 합니다.  
설정이 없으면 기본값이 적용되며, 일부 환경에서 위치 권한이 포함될 수 있습니다.

**권장 조치**: Podfile에 필요한 권한만 명시

```ruby
# ios/Podfile - post_install 블록에 추가
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NOTIFICATIONS=1',   # 알림만 사용
        'PERMISSION_LOCATION=0',        # 위치 비활성화
      ]
    end
  end
end
```

### (2) App Tracking Transparency(ATT)와 혼동

iOS 14.5+에서 "다른 앱에서의 활동 추적 허용" 다이얼로그가 먼저 뜰 수 있습니다.

- **위치**: "이 앱이 사용자의 위치에 액세스하도록 허용"
- **ATT**: "이 앱이 다른 회사의 앱에서 사용자 활동을 추적하도록 허용"

`in_app_review` 등 StoreKit 사용 시 ATT가 뜰 수 있으나, 이 앱에서는 ATT를 직접 요청하는 코드는 없습니다.

### (3) 다른 플러그인/의존성

직접 사용하는 코드는 없지만, 의존 패키지가 위치 권한을 요청할 가능성은 있습니다.  
`flutter pub deps`로 의존 트리를 확인해 보세요.

---

## 4. 권장 조치

1. **Podfile 수정**: 위 예시처럼 `PERMISSION_NOTIFICATIONS=1`, `PERMISSION_LOCATION=0` 설정
2. **클린 빌드**:
   ```bash
   cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
   flutter clean && flutter pub get
   ```
3. **Info.plist 확인**: `NSLocationWhenInUseUsageDescription` 등 위치 관련 키가 없어야 함 (현재 없음)
