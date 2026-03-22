// session_notifier.dart
// 세션 상태 관리 (Riverpod 3.0+ AsyncNotifier, Secure Storage 사용)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/session_secure_storage.dart';

/// 세션 상태
class SessionState {
  const SessionState({this.sessionToken, this.expiresAt, this.userId});

  final String? sessionToken;
  final String? expiresAt;
  final int? userId;

  bool get isLoggedIn =>
      sessionToken != null &&
      sessionToken!.isNotEmpty &&
      !_isExpired(expiresAt);

  static bool _isExpired(String? expiresAt) {
    if (expiresAt == null) return true;
    final dt = DateTime.tryParse(expiresAt);
    return dt == null || dt.isBefore(DateTime.now());
  }
}

/// SessionNotifier - 세션 상태 관리 (Secure Storage 기반)
class SessionNotifier extends AsyncNotifier<SessionState> {
  /// iOS 실기기에서 flutter_secure_storage 첫 접근 시 5~30초 hang 가능 → 타임아웃
  static const _storageTimeout = Duration(seconds: 10);

  @override
  Future<SessionState> build() async {
    if (kDebugMode) debugPrint('[SessionNotifier] build start');
    final token = await SessionSecureStorage.getSessionToken().timeout(
      _storageTimeout,
      onTimeout: () {
        if (kDebugMode) debugPrint('[SessionNotifier] getSessionToken TIMEOUT');
        return null;
      },
    );
    if (kDebugMode) debugPrint('[SessionNotifier] token done');
    final expires = await SessionSecureStorage.getSessionExpiresAt().timeout(
      _storageTimeout,
      onTimeout: () {
        if (kDebugMode)
          debugPrint('[SessionNotifier] getSessionExpiresAt TIMEOUT');
        return null;
      },
    );
    if (kDebugMode) debugPrint('[SessionNotifier] expires done');
    var userId = await SessionSecureStorage.getUserId().timeout(
      _storageTimeout,
      onTimeout: () {
        if (kDebugMode) debugPrint('[SessionNotifier] getUserId TIMEOUT');
        return null;
      },
    );
    if (kDebugMode) debugPrint('[SessionNotifier] userId done');
    if (token != null && expires != null) {
      final dt = DateTime.tryParse(expires);
      if (dt != null && dt.isAfter(DateTime.now())) {
        if (userId == null) {
          try {
            userId = await ApiClient().getMe(token);
            await SessionSecureStorage.saveSession(
              token,
              expires,
              userId: userId,
            );
          } catch (_) {
            // /me 실패 시 userId 없이 진행 (초대 버튼 등 일부 기능 제한)
          }
        }
        return SessionState(
          sessionToken: token,
          expiresAt: expires,
          userId: userId,
        );
      }
    }

    return const SessionState();
  }

  /// 로그인 성공 시 호출
  void setSession(String token, String expiresAt, int userId) {
    state = AsyncData(
      SessionState(sessionToken: token, expiresAt: expiresAt, userId: userId),
    );
  }

  /// 로그아웃
  Future<void> logout() async {
    final current = state.value;
    final token = current?.sessionToken;
    if (token != null) {
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await ApiClient().deactivatePushToken(token, fcmToken);
        }
      } catch (_) {}
      try {
        await ApiClient().logout(token);
      } catch (_) {}
    }
    await SessionSecureStorage.clearSession();
    state = const AsyncData(SessionState());
  }

  /// 회원 탈퇴
  Future<void> deleteAccount() async {
    final current = state.value;
    final token = current?.sessionToken;
    if (token == null) {
      await SessionSecureStorage.clearSession();
      await SessionSecureStorage.setHasEverLoggedIn(false);
      await AppStorage.setGuestBrowsingActive(false);
      state = const AsyncData(SessionState());
      return;
    }
    await ApiClient().deleteMe(token);
    await SessionSecureStorage.clearSession();
    await SessionSecureStorage.setHasEverLoggedIn(false);
    await AppStorage.setGuestBrowsingActive(false);
    state = const AsyncData(SessionState());
  }

  /// 로그인 성공 시 세션 저장 (Secure Storage + state)
  Future<void> loginSuccess(String token, String expiresAt, int userId) async {
    await SessionSecureStorage.setHasEverLoggedIn(true);
    await AppStorage.setGuestBrowsingActive(false);
    await SessionSecureStorage.saveSession(token, expiresAt, userId: userId);
    setSession(token, expiresAt, userId);

    // 로그인 직후 현재 디바이스 FCM 토큰을 서버에 등록
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ApiClient().upsertPushToken(
          token,
          token: fcmToken,
          platform: _currentPlatform(),
        );
        debugPrint('[FCM][LOGIN_SYNC][OK] platform=${_currentPlatform()}');
      } else {
        debugPrint('[FCM][LOGIN_SYNC][SKIP] token is empty');
      }
    } catch (e) {
      debugPrint('[FCM][LOGIN_SYNC][FAIL] $e');
      // FCM 동기화 실패는 로그인 성공을 막지 않는다.
    }
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

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
