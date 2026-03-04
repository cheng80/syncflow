# FCM iOS/Android 설정 가이드 (Riverpod 기본, 2026-03-05)

본 문서는 **Flutter + Riverpod** 조합을 기본 전제로 작성되었다.

## 목적

Flutter 앱에서 iOS/Android FCM 수신 준비를 완료하고,
Riverpod 기반으로 포그라운드/백그라운드 수신 경로를 표준화한다.

## 1. 의존성

```yaml
dependencies:
  flutter_riverpod: ^3.2.0
  firebase_core: ^4.5.0
  firebase_messaging: ^16.1.2
  flutter_local_notifications: ^19.4.2
  permission_handler: ^12.0.1
  flutter_secure_storage: ^9.0.0
  get_storage: ^2.1.1
```

권장 저장 전략:
- `flutter_secure_storage`: 세션 토큰, 사용자 식별값
- `get_storage`: 비민감 메타값(마지막 동기화 시각, 플래그)

## 2. iOS 설정

### 2-1. Info.plist

경로: `ios/Runner/Info.plist`

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

### 2-2. AppDelegate.swift

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 2-3. Podfile(permission_handler)

경로: `ios/Podfile`

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

## 3. Android 설정

경로: `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## 4. Riverpod 기본 부팅 구조

핵심:
- `main.dart`는 Firebase 초기화 + 앱 부팅만 담당
- FCM 상세 로직은 `FcmNotifier`로 분리
- 앱 부팅 직후 `initialize()` 1회 호출

```dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/firebase_options.dart';
import 'package:your_app/vm/fcm_notifier.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    runApp(const ProviderScope(child: AppBootstrap()));
  }, (error, stack) {
    debugPrint('Unhandled: $error\n$stack');
  });
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(fcmNotifierProvider.notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) => const MyApp();
}
```

## 5. FcmNotifier 표준 책임

`lib/vm/fcm_notifier.dart`에서 아래를 담당한다.

- 알림 권한 요청 (`permission_handler` + `FirebaseMessaging.requestPermission`)
- 초기 토큰 발급 (`getToken`) 및 서버 업서트
- 토큰 갱신 구독 (`onTokenRefresh`) 및 서버 재동기화
- 포그라운드 수신 구독 (`onMessage`) + 로컬 알림 표시
- 설정 앱 복귀 시 권한 재확인(`AppLifecycleListener.onResume`)

## 6. 포그라운드 수신(로컬 알림) 표준

```dart
const foregroundChannel = AndroidNotificationChannel(
  'app_foreground_push_v1',
  'Foreground Push',
  description: 'Show push in foreground',
  importance: Importance.high,
);

final localNotifications = FlutterLocalNotificationsPlugin();

Future<void> setupForegroundMessageHandler() async {
  await localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher_foreground'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(foregroundChannel);

  FirebaseMessaging.onMessage.listen((message) async {
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'App',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'app_foreground_push_v1',
          'Foreground Push',
          channelDescription: 'Show push in foreground',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_launcher_foreground',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  });
}
```

주의:
- Android 알림 채널 중요도는 생성 후 변경되지 않는다. 중요도 정책 변경 시 채널 ID를 새로 만든다.

## 7. 검증 체크리스트

- [ ] iOS 실기기 권한 허용 후 토큰 발급 성공
- [ ] Android 실기기/에뮬레이터 토큰 발급 성공
- [ ] `onTokenRefresh` 발생 시 서버 업서트 성공
- [ ] 포그라운드 수신 시 로컬 알림 표시 성공
- [ ] 백그라운드 수신 시 시스템 알림 표시 성공

## 비-Riverpod 프로젝트 메모

Riverpod을 사용하지 않는 경우에도,
`initialize -> permission -> getToken/upsert -> onTokenRefresh -> onMessage(local notify)`
순서를 동일하게 유지해서 적용하면 된다.

## 공식 문서

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/flutter/receive
- https://pub.dev/packages/firebase_messaging
- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/permission_handler
