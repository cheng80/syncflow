// session_notifier.dart
// 세션 상태 관리 (Riverpod 3.0+ AsyncNotifier, Secure Storage 사용)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/session_secure_storage.dart';

/// 세션 상태
class SessionState {
  const SessionState({
    this.sessionToken,
    this.expiresAt,
    this.userId,
  });

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
  @override
  Future<SessionState> build() async {
    final token = await SessionSecureStorage.getSessionToken();
    final expires = await SessionSecureStorage.getSessionExpiresAt();
    var userId = await SessionSecureStorage.getUserId();
    if (token != null && expires != null) {
      final dt = DateTime.tryParse(expires);
      if (dt != null && dt.isAfter(DateTime.now())) {
        if (userId == null) {
          try {
            userId = await ApiClient().getMe(token);
            await SessionSecureStorage.saveSession(token, expires, userId: userId);
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
    state = AsyncData(SessionState(
      sessionToken: token,
      expiresAt: expiresAt,
      userId: userId,
    ));
  }

  /// 로그아웃
  Future<void> logout() async {
    final current = state.value;
    final token = current?.sessionToken;
    if (token != null) {
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
      state = const AsyncData(SessionState());
      return;
    }
    await ApiClient().deleteMe(token);
    await SessionSecureStorage.clearSession();
    state = const AsyncData(SessionState());
  }

  /// 로그인 성공 시 세션 저장 (Secure Storage + state)
  Future<void> loginSuccess(String token, String expiresAt, int userId) async {
    await SessionSecureStorage.saveSession(token, expiresAt, userId: userId);
    setSession(token, expiresAt, userId);
  }
}

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
