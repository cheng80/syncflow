import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/common_util.dart';
import 'package:syncflow/util/session_secure_storage.dart';
import 'package:syncflow/view/board_detail_screen.dart';

class FcmNotifier extends Notifier<bool> {
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  StreamSubscription<RemoteMessage>? _fcmOpenedAppSubscription;
  AppLifecycleListener? _appLifecycleListener;
  Timer? _permissionRecheckTimer;
  int _permissionRecheckAttempt = 0;
  String? _lastHandledNavKey;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
    'syncflow_foreground_push_v2',
    'Foreground Push',
    description: 'Show push notifications while app is in foreground',
    importance: Importance.high,
  );
  static const List<Duration> _permissionRecheckDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
  ];

  @override
  bool build() {
    ref.onDispose(_dispose);
    return false;
  }

  Future<void> initialize() async {
    if (state) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      return;
    }

    state = true;
    unawaited(_initLocalNotifications());
    unawaited(_initFcmAndPermission());
    _setupFcmTokenRefreshListener();
    _setupForegroundPushListener();
    _setupNotificationTapListeners();
    _setupPermissionResumeListener();
  }

  void _dispose() {
    _fcmTokenRefreshSubscription?.cancel();
    _fcmForegroundSubscription?.cancel();
    _fcmOpenedAppSubscription?.cancel();
    _appLifecycleListener?.dispose();
    _permissionRecheckTimer?.cancel();
  }

  Future<void> _initLocalNotifications() async {
    // Android는 drawable 리소스를 권장한다. mipmap 아이콘 사용 시 초기화가 실패할 수 있다.
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          final decoded = _decodePayload(payload);
          if (decoded == null) return;
          unawaited(_handlePushNavigation(decoded));
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_foregroundChannel);
    } catch (e) {
      debugPrint('Local notifications init skipped: $e');
    }
  }

  Future<void> _initFcmAndPermission() async {
    if (Firebase.apps.isEmpty) return;
    await _runPermissionRecheck();
  }

  Future<void> _requestNotificationPermission() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        // 자동으로 설정 앱을 열지 않는다. (사용자 의도 없는 강제 이동 방지)
        return;
      }

      if (status.isDenied) {
        final result = await Permission.notification.request();

        if (result.isPermanentlyDenied && !await _isFcmAuthorized()) return;
      }

      // Android 13+/iOS 모두 FCM 권한 상태를 재확인한다.
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied.');
      }
    } catch (e) {
      debugPrint('Notification permission check skipped: $e');
    }
  }

  void _setupPermissionResumeListener() {
    _appLifecycleListener?.dispose();
    _appLifecycleListener = AppLifecycleListener(
      onResume: () async {
        try {
          if (_permissionRecheckTimer == null && _permissionRecheckAttempt == 0) {
            return;
          }
          await _runPermissionRecheck();
        } catch (e) {
          debugPrint('Permission resume check skipped: $e');
        }
      },
    );
  }

  void _schedulePermissionRecheck() {
    if (_permissionRecheckAttempt >= _permissionRecheckDelays.length) {
      debugPrint('Permission/token recheck max attempts reached.');
      return;
    }
    _permissionRecheckTimer?.cancel();
    final delay = _permissionRecheckDelays[_permissionRecheckAttempt];
    _permissionRecheckAttempt += 1;
    _permissionRecheckTimer = Timer(delay, () {
      unawaited(_runPermissionRecheck());
    });
  }

  void _clearPermissionRecheck() {
    _permissionRecheckTimer?.cancel();
    _permissionRecheckTimer = null;
    _permissionRecheckAttempt = 0;
  }

  Future<void> _runPermissionRecheck() async {
    await _requestNotificationPermission();
    final granted = await _isNotificationPermissionGranted();
    if (!granted) {
      _schedulePermissionRecheck();
      return;
    }

    final synced = await _syncCurrentFcmTokenIfLoggedIn();
    if (!synced) {
      _schedulePermissionRecheck();
      return;
    }
    _clearPermissionRecheck();
  }

  Future<bool> _isNotificationPermissionGranted() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
    } catch (_) {}
    return _isFcmAuthorized();
  }

  Future<bool> _isFcmAuthorized() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> _syncCurrentFcmTokenIfLoggedIn() async {
    final sessionToken = await SessionSecureStorage.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) return true;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM][TOKEN_SYNC][RETRY] token is empty');
        return false;
      }
      await ApiClient().upsertPushToken(
        sessionToken,
        token: token,
        platform: _currentPlatform(),
      );
      debugPrint('[FCM][TOKEN_SYNC][OK] platform=${_currentPlatform()}');
      return true;
    } catch (e) {
      debugPrint('[FCM][TOKEN_SYNC][FAIL] $e');
      return false;
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
          debugPrint('[FCM][TOKEN_REFRESH_SYNC][OK] platform=${_currentPlatform()}');
        } catch (e) {
          debugPrint('[FCM][TOKEN_REFRESH_SYNC][FAIL] $e');
        }
      },
      onError: (error) {
        debugPrint('FCM onTokenRefresh error: $error');
      },
    );
  }

  void _setupForegroundPushListener() {
    _fcmForegroundSubscription?.cancel();
    _fcmForegroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) async {
        final notification = message.notification;
        final title = notification?.title ?? message.data['title']?.toString();
        final body = notification?.body ?? message.data['body']?.toString();

        if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
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
            payload: jsonEncode({
              ...message.data,
              if (message.messageId != null) 'message_id': message.messageId,
            }),
          );
        } catch (e) {
          debugPrint('Foreground push local notify failed: $e');
        }
      },
      onError: (error) {
        debugPrint('FCM onMessage error: $error');
      },
    );
  }

  void _setupNotificationTapListeners() {
    _fcmOpenedAppSubscription?.cancel();
    _fcmOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        unawaited(_handlePushNavigation(message.data));
      },
      onError: (error) {
        debugPrint('FCM onMessageOpenedApp error: $error');
      },
    );

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      unawaited(_handlePushNavigation(message.data));
    }).catchError((e) {
      debugPrint('FCM getInitialMessage skipped: $e');
    });
  }

  Map<String, dynamic>? _decodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> _handlePushNavigation(Map<String, dynamic>? data) async {
    if (data == null || data.isEmpty) return;

    final boardId = _toInt(data['board_id']);
    if (boardId == null || boardId <= 0) return;
    final cardId = _toInt(data['card_id']);
    final navKey = '$boardId:${cardId ?? 0}:${data['event_type'] ?? ''}';
    if (_lastHandledNavKey == navKey) return;
    _lastHandledNavKey = navKey;

    final sessionToken = await SessionSecureStorage.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) return;

    final nav = rootNavigatorKey.currentState;
    final ctx = nav?.context;
    if (nav == null || ctx == null || !ctx.mounted) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => BoardDetailScreen(
          boardId: boardId,
          title: 'Board #$boardId',
          ownerId: null,
          initialCardId: cardId,
        ),
      ),
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
