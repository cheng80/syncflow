import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/session_secure_storage.dart';

class FcmNotifier extends Notifier<bool> {
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  AppLifecycleListener? _appLifecycleListener;
  bool _openedNotificationSettings = false;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
    'syncflow_foreground_push_v2',
    'Foreground Push',
    description: 'Show push notifications while app is in foreground',
    importance: Importance.high,
  );

  @override
  bool build() {
    ref.onDispose(_dispose);
    return false;
  }

  Future<void> initialize() async {
    debugPrint('FCM initialize called. state=$state, firebaseApps=${Firebase.apps.length}');
    if (state) {
      debugPrint('FCM initialize skipped: already initialized');
      return;
    }
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM initialize skipped: Firebase not initialized');
      return;
    }

    state = true;
    unawaited(_initLocalNotifications());
    unawaited(_initFcmAndPermission());
    _setupFcmTokenRefreshListener();
    _setupForegroundPushListener();
    _setupPermissionResumeListener();
    debugPrint('FCM initialize done: listeners attached');
  }

  void _dispose() {
    _fcmTokenRefreshSubscription?.cancel();
    _fcmForegroundSubscription?.cancel();
    _appLifecycleListener?.dispose();
  }

  Future<void> _initLocalNotifications() async {
    // Android는 drawable 리소스를 권장한다. mipmap 아이콘 사용 시 초기화가 실패할 수 있다.
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      debugPrint('FCM local notifications init start');
      await _localNotifications.initialize(settings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_foregroundChannel);
      debugPrint('FCM local notifications init done');
    } catch (e) {
      debugPrint('Local notifications init skipped: $e');
    }
  }

  Future<void> _initFcmAndPermission() async {
    if (Firebase.apps.isEmpty) return;
    debugPrint('FCM permission/token init start');
    await _requestNotificationPermission();
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $fcmToken');
      await _syncCurrentFcmTokenIfLoggedIn();
      debugPrint('FCM permission/token init done');
    } catch (e) {
      debugPrint('FCM token skipped: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        debugPrint('Notification permission permanently denied.');
        _openedNotificationSettings = true;
        unawaited(openAppSettings());
        return;
      }

      if (status.isDenied || status.isRestricted) {
        final result = await Permission.notification.request();
        debugPrint('Notification permission: $result');

        if (result.isPermanentlyDenied || result.isRestricted) {
          debugPrint('Notification permission blocked.');
          _openedNotificationSettings = true;
          unawaited(openAppSettings());
          return;
        }
      } else {
        debugPrint('Notification permission already: $status');
      }

      // Android 13+/iOS 모두 FCM 권한 상태를 재확인한다.
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM auth status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Notification permission check skipped: $e');
    }
  }

  void _setupPermissionResumeListener() {
    _appLifecycleListener?.dispose();
    _appLifecycleListener = AppLifecycleListener(
      onResume: () async {
        if (!_openedNotificationSettings) return;

        try {
          final status = await Permission.notification.status;
          debugPrint('Notification permission on resume: $status');

          if (status.isGranted) {
            _openedNotificationSettings = false;
            await _syncCurrentFcmTokenIfLoggedIn();
            debugPrint('FCM token resynced after settings return.');
          }
        } catch (e) {
          debugPrint('Permission resume check skipped: $e');
        }
      },
    );
  }

  Future<void> _syncCurrentFcmTokenIfLoggedIn() async {
    final sessionToken = await SessionSecureStorage.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await ApiClient().upsertPushToken(
        sessionToken,
        token: token,
        platform: _currentPlatform(),
      );
    } catch (e) {
      debugPrint('FCM initial sync skipped: $e');
    }
  }

  void _setupFcmTokenRefreshListener() {
    _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        final sessionToken = await SessionSecureStorage.getSessionToken();
        if (sessionToken == null || sessionToken.isEmpty) return;

        try {
          await ApiClient().upsertPushToken(
            sessionToken,
            token: newToken,
            platform: _currentPlatform(),
          );
        } catch (e) {
          debugPrint('FCM refresh sync failed: $e');
        }
      },
      onError: (error) {
        debugPrint('FCM onTokenRefresh error: $error');
      },
    );
  }

  void _setupForegroundPushListener() {
    debugPrint('FCM onMessage listener setup');
    _fcmForegroundSubscription?.cancel();
    _fcmForegroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) async {
        final receivedLog =
            'FCM foreground message received: id=${message.messageId}, '
            'hasNotification=${message.notification != null}, data=${message.data}';
        debugPrint(receivedLog);
        final notification = message.notification;
        final title = notification?.title ?? message.data['title']?.toString();
        final body = notification?.body ?? message.data['body']?.toString();

        if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
          const skippedLog = 'FCM foreground local notify skipped: empty title/body';
          debugPrint(skippedLog);
          return;
        }

        try {
          await _localNotifications.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title ?? 'SyncFlow',
            body ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'syncflow_foreground_push_v2',
                'Foreground Push',
                channelDescription:
                    'Show push notifications while app is in foreground',
                icon: 'ic_launcher_foreground',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: message.messageId,
          );
          final shownLog =
              'FCM foreground local notify shown: title=$title, body=$body';
          debugPrint(shownLog);
        } catch (e) {
          final failedLog = 'Foreground push local notify failed: $e';
          debugPrint(failedLog);
        }
      },
      onError: (error) {
        final errorLog = 'FCM onMessage error: $error';
        debugPrint(errorLog);
      },
    );
  }
}

String _currentPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'web';
  }
}

final fcmNotifierProvider = NotifierProvider<FcmNotifier, bool>(
  FcmNotifier.new,
);
