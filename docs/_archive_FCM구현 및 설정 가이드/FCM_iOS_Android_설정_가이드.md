# Flutter FCM (Firebase Cloud Messaging) 설정 가이드

이 문서는 **Flutter + Firebase Cloud Messaging(FCM)** 환경에서 **iOS 및 Android 실기기에서 푸시 토큰을 정상적으로 발급받고, 서버(FastAPI)에서 푸시 테스트까지 가능**하게 만드는 **최소 필수 설정**을 정리한 가이드다.

> 목적: 프로젝트 팀원들이 FCM 설정을 참고할 수 있도록 현재 프로젝트에 적용된 설정을 문서화

---

## 0. 전제 조건

- Firebase 프로젝트 생성 완료
- Flutter 프로젝트가 Firebase에 연결됨 (`firebase_core`, `firebase_messaging` 설치 완료)
- Apple Developer Program 가입 완료 (iOS용)
- Firebase 콘솔에 **APNs Auth Key (.p8)** 업로드 완료 (iOS용)
- **실기기** 사용 권장 (iOS 시뮬레이터는 FCM 토큰 발급 불가, Android 에뮬레이터는 Google Play Services 설치 시 가능)

---

## 1. Flutter 패키지 의존성

`pubspec.yaml`에 다음 패키지가 포함되어 있어야 합니다:

```yaml
dependencies:
  firebase_core: ^4.3.0
  firebase_messaging: ^16.1.0
  flutter_riverpod: ^3.1.0  # FCM 상태 관리용
```

> `flutter pub get` 실행

---

## 2. iOS Info.plist 필수 설정

경로: `ios/Runner/Info.plist`

아래 항목이 **반드시 존재**해야 합니다:

```xml
<!-- 알림 권한 설명 -->
<key>NSUserNotificationsUsageDescription</key>
<string>알림을 위해 필요합니다.</string>

<!-- 백그라운드 푸시 허용 -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<!-- Firebase AppDelegate Proxy: false로 설정하여 수동으로 APNs 토큰 처리 -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### 설정 설명

- `NSUserNotificationsUsageDescription`: 알림 권한 요청 시 사용자에게 표시되는 설명
- `UIBackgroundModes`: 백그라운드에서 푸시 알림을 받기 위한 필수 설정
- `FirebaseAppDelegateProxyEnabled`: `false`로 설정하여 AppDelegate에서 APNs 토큰을 수동으로 처리

---

## 3. iOS Runner.entitlements 파일 생성

경로: `ios/Runner/Runner.entitlements`

**⚠️ 중요: 이 파일이 없으면 "유효한 'aps-environment' 인타이틀먼트 문자열을 찾을 수 없습니다" 에러 발생**

파일 생성:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
```

### Xcode 프로젝트에 연결

`ios/Runner.xcodeproj/project.pbxproj`의 Debug 및 Release 빌드 설정에 추가:

```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

또는 Xcode에서:
1. Runner 타겟 선택
2. Build Settings → Code Signing Entitlements
3. `Runner/Runner.entitlements` 입력

### 프로덕션 빌드 시

`aps-environment` 값을 `production`으로 변경:

```xml
<key>aps-environment</key>
<string>production</string>
```

---

## 4. iOS AppDelegate.swift 필수 설정

경로: `ios/Runner/AppDelegate.swift`

**⚠️ 중요: `FirebaseApp.configure()`를 호출하지 않습니다! FlutterFire 플러그인이 자동으로 처리합니다.**

아래 구조를 **그대로 유지**해야 합니다:

```swift
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Firebase 초기화는 FlutterFire 플러그인이 자동으로 처리합니다
    // Flutter의 main.dart에서 Firebase.initializeApp()을 호출하므로
    // 여기서 중복 호출하면 크래시가 발생할 수 있습니다

    // FCM을 위한 UNUserNotificationCenter delegate 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // FirebaseAppDelegateProxyEnabled가 false이므로 수동으로 APNs 등록 요청
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs 토큰 등록 (FCM 토큰을 받기 위해 필요)
  // FirebaseAppDelegateProxyEnabled가 false이므로 수동으로 처리해야 함
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Firebase Messaging에 APNs 토큰 전달 (수동 처리)
    Messaging.messaging().apnsToken = deviceToken
    
    print("✅ APNs token registered successfully")
    
    // 부모 클래스 메서드도 호출
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs 토큰 등록 실패 처리
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
```

### 핵심 포인트

- **`FirebaseApp.configure()` 호출하지 않음**: FlutterFire가 자동 처리 (중복 호출 시 크래시)
- `UNUserNotificationCenter.current().delegate = self` 필수: 알림 delegate 설정
- `registerForRemoteNotifications()` 필수: APNs 등록 요청
- APNs 토큰을 FCM에 연결 (`Messaging.messaging().apnsToken = deviceToken`) 필수

---

## 5. Android AndroidManifest.xml 필수 설정

경로: `android/app/src/main/AndroidManifest.xml`

아래 권한과 메타데이터가 **반드시 존재**해야 합니다:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- FCM 푸시 알림 권한 -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="com.google.android.c2dm.permission.RECEIVE"/>

    <application>
        <!-- Firebase Cloud Messaging 기본 채널 설정 (Android 8.0 이상) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
        
        <!-- Firebase Cloud Messaging 기본 알림 아이콘 -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />
        
        <!-- Firebase Cloud Messaging 기본 알림 색상 (선택사항) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@android:color/transparent" />
    </application>
</manifest>
```

### 설정 설명

- `POST_NOTIFICATIONS`: Android 13 (API 33) 이상에서 알림 권한
- `WAKE_LOCK`: 백그라운드에서 알림 수신을 위한 기기 깨우기 권한
- `com.google.android.c2dm.permission.RECEIVE`: FCM 메시지 수신 권한
- FCM 메타데이터: 알림 채널, 아이콘, 색상 설정

---

## 6. Android build.gradle.kts 확인

경로: `android/app/build.gradle.kts`

다음 플러그인이 포함되어 있어야 합니다:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")  // Firebase 플러그인
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
```

또한 `android/app/google-services.json` 파일이 존재해야 합니다.

---

## 7. Flutter FCM Notifier 구현

경로: `lib/vm/fcm_notifier.dart`

프로젝트에서는 Riverpod을 사용하여 FCM 상태를 관리합니다.

**⚠️ 중요: iOS에서는 APNs 토큰이 등록될 때까지 대기해야 합니다.**

```dart
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_now_app/utils/fcm_storage.dart';

class FCMNotifier extends Notifier<FCMState> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // iOS 알림 권한 요청
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS: APNs 토큰이 등록될 때까지 대기 (필수!)
      await _waitForAPNSToken();
    }

    // 초기 토큰 가져오기
    await _refreshToken();
    
    // 토큰 갱신 리스너 설정
    _setupTokenRefreshListener();

    // 포그라운드 메시지 핸들러 설정
    _setupForegroundMessageHandler();
  }

  /// iOS: APNs 토큰이 등록될 때까지 대기
  ///
  /// APNs 토큰이 등록되어야 FCM 토큰을 받을 수 있습니다.
  /// 최대 10초까지 대기하며, 0.5초마다 확인합니다.
  Future<void> _waitForAPNSToken() async {
    if (!Platform.isIOS) return;

    const maxAttempts = 20; // 10초 (0.5초 * 20)
    const delayDuration = Duration(milliseconds: 500);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          if (kDebugMode) {
            print('✅ APNs token received');
          }
          return;
        }
      } catch (e) {
        // APNs 토큰이 아직 없음, 계속 대기
      }

      if (kDebugMode && attempt == 0) {
        print('⏳ Waiting for APNs token...');
      }

      await Future.delayed(delayDuration);
    }

    if (kDebugMode) {
      print('⚠️  APNs token not received after 10 seconds. FCM token may not be available.');
    }
  }

  /// 토큰 새로고침
  Future<void> _refreshToken() async {
    try {
      final token = await _messaging.getToken();

      // 토큰을 로컬에 저장
      if (token != null) {
        await FCMStorage.saveFCMToken(token);
      }

      state = state.copyWith(token: token, removeErrorMessage: true);

      if (kDebugMode && token != null) {
        print('🔥 FCM_TOKEN updated: $token');
        print('💾 FCM 토큰 로컬 저장 완료');
      } else if (kDebugMode && token == null) {
        print('⚠️  FCM token is null.');
        print('💡 실기기에서 실행하거나, Google Play Services가 설치된 환경에서 실행하세요.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get FCM token: $e');
        print('💡 실기기에서 실행하거나, Google Play Services가 설치된 환경에서 실행하세요.');
      }
      state = state.copyWith(errorMessage: '토큰을 가져오는 중 오류가 발생했습니다.');
    }
  }

  /// 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      // 새 토큰을 로컬에 저장
      await FCMStorage.saveFCMToken(newToken);

      // 서버 동기화 상태 초기화 (새 토큰이므로 서버에 전송 필요)
      await FCMStorage.clearSyncStatus();

      state = state.copyWith(token: newToken);

      if (kDebugMode) {
        print('🔄 FCM_TOKEN refreshed: $newToken');
        print('💾 새 토큰 로컬 저장 완료');
        print('⚠️  서버에 새 토큰 전송이 필요합니다.');
      }
    });
  }

  /// 포그라운드 메시지 핸들러 설정
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📨 Foreground message received: ${message.notification?.title}');
      }
      // TODO: 포그라운드 알림 표시 로직 구현
      // 포그라운드 상태에서는 FCM이 자동으로 알림을 표시하지 않으므로
      // flutter_local_notifications 패키지를 사용하여 로컬 노티피케이션을 표시해야 함
      // 예: LocalNotificationService.showNotification(message);
    });
  }
}

final fcmNotifierProvider = NotifierProvider<FCMNotifier, FCMState>(
  FCMNotifier.new,
);
```

---

## 8. Flutter main.dart 초기화

경로: `lib/main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:table_now_app/config.dart';
import 'package:table_now_app/firebase_options.dart';
import 'package:table_now_app/view/home.dart';
import 'package:table_now_app/vm/fcm_notifier.dart';
import 'package:table_now_app/vm/theme_notifier.dart';

Future<void> main() async {
  // Flutter 바인딩 초기화 (플러그인 사용 전 필수)
  WidgetsFlutterBinding.ensureInitialized();

  // GetStorage 초기화
  await GetStorage.init();

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('✅ Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Firebase initialization error: $e');
    }
  }

  // API 기본 URL 초기화 (실기기 여부 체크 포함)
  try {
    await initializeApiBaseUrl();
    if (kDebugMode) {
      print('✅ API Base URL initialized: ${getApiBaseUrl()}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️  API Base URL initialization error: $e');
      print('💡 기본값을 사용합니다: ${getApiBaseUrl()}');
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // FCM 초기화 (Firebase 초기화 후 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFCM();
    });
  }

  Future<void> _initializeFCM() async {
    try {
      await ref.read(fcmNotifierProvider.notifier).initialize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM initialization error: $e');
      }
      // FCM 초기화 실패해도 앱은 계속 실행
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod으로 테마 모드 관리
    final themeMode = ref.watch(themeNotifierProvider);
    final Color seedColor = Colors.deepPurple;

    return MaterialApp(
      title: 'Table Now',
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: seedColor,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: seedColor,
      ),
      home: const Home(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### 성공 기준

콘솔 또는 Xcode/Android Studio 로그에 아래가 출력되면 성공:

```
🚀 FCM 초기화 시작...
📱 Platform: iOS (또는 Android)
✅ FCM initialized successfully
🔥 FCM_TOKEN = eYJ0...긴문자열
```

---

## 9. iOS 빌드/실행 주의사항

### 반드시 지킬 것

- **실기기에서 실행** (시뮬레이터는 FCM 토큰 발급 불가)
- 앱 삭제 후 재설치 권장 (권한/토큰 초기화 목적)
- Xcode에서 **Push Notifications Capability** 활성화 확인
- **Runner.entitlements 파일 생성 및 연결 확인**
- 실행 명령:

```bash
flutter run -d <iPhoneDeviceName>
```

### Xcode에서 Push Notifications Capability 활성화

1. Xcode에서 프로젝트 열기 (`ios/Runner.xcworkspace`)
2. Runner 타겟 선택
3. **Signing & Capabilities** 탭
4. **"+ Capability"** 클릭
5. **"Push Notifications"** 추가
6. Xcode가 자동으로 `aps-environment`를 설정합니다

### 프로비저닝 프로파일 갱신

Push Notifications Capability를 추가한 후:

1. **"Automatically manage signing"** 체크 확인
2. Team 선택 후 잠시 대기 (Xcode가 프로비저닝 프로파일 자동 갱신)
3. 에러가 있으면 빨간색으로 표시됨
4. 에러 발생 시:
   - Apple Developer Portal에서 App ID 확인
   - Push Notifications가 활성화되어 있는지 확인
   - 프로비저닝 프로파일 재생성

### Apple Developer Portal 확인

1. https://developer.apple.com 접속
2. Certificates, Identifiers & Profiles
3. Identifiers → App IDs
4. `com.team01.tablenowapp` 선택
5. Push Notifications가 활성화되어 있는지 확인
6. 활성화되어 있지 않으면:
   - Edit 클릭
   - Push Notifications 체크
   - Save
   - Xcode로 돌아와서 프로비저닝 프로파일 갱신

---

## 10. Android 빌드/실행 주의사항

### 에뮬레이터 vs 실기기

- **Google Play Services가 설치된 에뮬레이터**: FCM 토큰 발급 및 푸시 알림 수신 가능 ✅
- **Google Play Services가 없는 에뮬레이터 (AOSP)**: FCM 작동하지 않을 수 있음 ❌
- **실기기**: 항상 작동 ✅

### 확인 방법

에뮬레이터에 Google Play Store 앱이 있으면 Google Play Services가 설치된 것입니다.

---

## 11. 플랫폼별 FCM 지원 현황

| 플랫폼 | 시뮬레이터/에뮬레이터 | FCM 토큰 | 푸시 알림 |
|--------|---------------------|---------|----------|
| iOS | 시뮬레이터 | ❌ 불가능 | ❌ 불가능 |
| iOS | 실기기 | ✅ 가능 | ✅ 가능 |
| Android | Google Play Services 있는 에뮬레이터 | ✅ 가능 | ✅ 가능 |
| Android | Google Play Services 없는 에뮬레이터 | ❌ 불가능 | ❌ 불가능 |
| Android | 실기기 | ✅ 가능 | ✅ 가능 |

---

## 12. FastAPI 연동 전 최소 확인 체크리스트

- [x] iOS: `Info.plist`에 필수 설정 추가 완료
- [x] iOS: `Runner.entitlements` 파일 생성 및 프로젝트 연결 완료
- [x] iOS: `AppDelegate.swift`에 필수 메서드 구현 완료 (FirebaseApp.configure() 제외)
- [x] iOS: Xcode에서 Push Notifications Capability 활성화 완료
- [x] iOS: 프로비저닝 프로파일 갱신 완료
- [x] iOS: Apple Developer Portal에서 App ID의 Push Notifications 활성화 확인
- [x] Android: `AndroidManifest.xml`에 필수 권한 및 메타데이터 추가 완료
- [x] Android: `google-services.json` 파일 존재 확인
- [x] Flutter: `firebase_core`, `firebase_messaging` 패키지 설치 완료
- [x] Flutter: `FCMNotifier` 구현 및 초기화 완료 (APNs 토큰 대기 로직 포함)
- [x] 실기기에서 FCM 토큰 발급 성공 확인

✅ **모든 항목 완료** - 서버 푸시 테스트 진행 가능

---

## 13. 다음 단계 (이 문서 이후 작업)

1. FastAPI에 `/api/notifications/register-token` 엔드포인트 구현
2. FCM 토큰을 서버로 전달
3. 실제 푸시 수신 확인
4. 이후 DB 구조(`device_tokens`, `push_logs`) 설계
5. 예약 완료 트리거 연동

---

## 14. 문제 해결

### iOS에서 토큰을 받지 못하는 경우

#### 에러: "유효한 'aps-environment' 인타이틀먼트 문자열을 찾을 수 없습니다"

**원인**: `Runner.entitlements` 파일이 없거나 프로젝트에 연결되지 않음

**해결**:
1. `ios/Runner/Runner.entitlements` 파일 생성 확인
2. Xcode에서 프로젝트에 파일 추가 확인
3. Build Settings → Code Signing Entitlements 확인
4. 프로비저닝 프로파일 갱신

#### 에러: "APNS token has not been received on the device yet"

**원인**: APNs 토큰이 등록되기 전에 FCM 토큰을 요청함

**해결**:
1. `_waitForAPNSToken()` 메서드가 구현되어 있는지 확인
2. iOS에서 알림 권한이 허용되어 있는지 확인
3. 실기기에서 실행 중인지 확인 (시뮬레이터 불가)
4. Xcode 로그에서 `APNs token registered successfully` 메시지 확인

#### 앱이 크래시하는 경우

**원인**: `FirebaseApp.configure()` 중복 호출

**해결**:
1. `AppDelegate.swift`에서 `FirebaseApp.configure()` 제거 확인
2. FlutterFire 플러그인이 자동으로 처리하므로 수동 호출 불필요

#### 일반적인 문제 해결 순서

1. **실기기에서 실행 중인지 확인** (시뮬레이터 불가)
2. **Runner.entitlements 파일 생성 및 연결 확인**
3. **Xcode에서 Push Notifications Capability 활성화 확인**
4. **프로비저닝 프로파일 갱신** (Signing & Capabilities에서 Team 재선택)
5. **Apple Developer Portal에서 App ID의 Push Notifications 활성화 확인**
6. **Firebase Console에 APNs Auth Key (.p8) 업로드 확인**
7. **앱 삭제 후 재설치** (권한/토큰 초기화)
8. **Xcode 로그 확인**: `APNs token registered successfully` 메시지 확인

### Android에서 토큰을 받지 못하는 경우

1. **Google Play Services 설치 확인** (에뮬레이터인 경우)
2. **`google-services.json` 파일 존재 확인**
3. **`build.gradle.kts`에 `com.google.gms.google-services` 플러그인 확인**
4. **앱 삭제 후 재설치**

---

## 요약

- 이 문서는 **iOS 및 Android FCM 토큰 발급을 위한 최소 설정 문서**입니다
- 프로젝트에 실제로 적용된 설정을 반영하여 작성되었습니다
- DB/예약 로직은 이 단계 이후 진행합니다

---

## 수정 이력

- 2026-01-17: 초기 문서 작성
  - iOS 및 Android FCM 설정 가이드 작성
  - 현재 프로젝트 설정 반영
  - 플랫폼별 지원 현황 및 문제 해결 가이드 추가

- 2026-01-17: 실제 문제 해결 과정 반영
  - Runner.entitlements 파일 생성 가이드 추가
  - AppDelegate.swift에서 FirebaseApp.configure() 제거 (중복 초기화 방지)
  - APNs 토큰 대기 로직 (_waitForAPNSToken) 추가
  - 프로비저닝 프로파일 갱신 가이드 추가
  - Apple Developer Portal 확인 절차 추가
  - 실제 발생한 에러 및 해결 방법 상세화
