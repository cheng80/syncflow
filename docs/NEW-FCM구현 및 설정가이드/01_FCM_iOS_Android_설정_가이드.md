# FCM iOS/Android 설정 가이드 (공용, 2026-03-04 검증)

## 목적

Flutter 앱에서 iOS/Android 실기기 기준으로 FCM 토큰 발급과 수신 준비를 완료한다.

## 공용값 + SyncFlow 예시

| 항목 | 공용 Placeholder | SyncFlow 예시 |
|---|---|---|
| Android `applicationId` | `<APP_PACKAGE>` | `com.cheng80.syncflow` |
| Android `namespace` | `<APP_PACKAGE>` | `com.cheng80.syncflow` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `<APP_PACKAGE>` | `com.cheng80.syncflow` |
| Dart package import | `<DART_PACKAGE>` | `syncflow` |
| API Base URL (dev) | `<BACKEND_BASE_URL>` | `http://10.0.2.2:8000` / `http://127.0.0.1:8000` |

## 공식 기준(현 시점)

- Firebase Flutter 시작 가이드: method swizzling 필수(Apple)
- iOS는 Push Notifications + Background Modes(Background fetch, Remote notifications) 활성화 필요
- 토큰 갱신은 `onTokenRefresh`로 구독

## 1. 의존성

### 공용 버전

```yaml
dependencies:
  firebase_core: ^4.4.0
  firebase_messaging: ^16.1.1
```

### SyncFlow 버전

```yaml
dependencies:
  flutter_riverpod: ^3.2.0
  # 기존 의존성 유지

  # FCM 추가
  firebase_core: ^4.4.0
  firebase_messaging: ^16.1.1
```

## 2. iOS 설정

### 2-1. Info.plist

#### 공용 버전

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>알림 수신을 위해 필요합니다.</string>
```

#### SyncFlow 버전

경로: `ios/Runner/Info.plist`

```xml
<key>CFBundleDisplayName</key>
<string>SyncFlow</string>

<key>NSUserNotificationsUsageDescription</key>
<string>보드 멘션/담당 변경 알림 수신을 위해 필요합니다.</string>
```

### 2-2. AppDelegate

#### 공용 버전

```swift
import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

#### SyncFlow 버전

경로: `ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // SyncFlow: FCM 도입 시 유지
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 3. Android 설정

### 공용 버전

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### SyncFlow 버전

경로: `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

(현재 SyncFlow manifest 권한 구조와 동일)

## 4. Flutter 초기화

### 공용 버전

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### SyncFlow 버전

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:syncflow/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 기존 SyncFlow runApp 구조 유지
  runApp(const MyApp());
}
```

## 5. 토큰 발급/갱신

### 공용 버전

```dart
final messaging = FirebaseMessaging.instance;

Future<String?> initFcmToken() async {
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    // TODO: 서버 갱신 API 호출
  });

  return token;
}
```

### SyncFlow 버전

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:syncflow/util/common_util.dart'; // getApiBaseUrl()

final messaging = FirebaseMessaging.instance;

Future<String?> initSyncFlowFcmToken() async {
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final baseUrl = getApiBaseUrl();
    // 권장 추가안: POST $baseUrl/v1/push-tokens
    // body: { user_id, platform, token }
  });

  return token;
}
```

## 6. 검증 체크리스트

- [ ] iOS 실기기에서 권한 허용 후 토큰 발급 성공
- [ ] Android 실기기/에뮬레이터에서 토큰 발급 성공
- [ ] 앱 재실행 시 `onTokenRefresh` 동작 확인
- [ ] Firebase Console 테스트 메시지 수신 확인(백그라운드)

## 공식 문서

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/flutter/client
- https://pub.dev/documentation/firebase_core/latest/
- https://pub.dev/documentation/firebase_messaging/latest/
