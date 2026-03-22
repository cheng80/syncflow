// session_secure_storage.dart
// 세션 토큰 등 민감 데이터를 FlutterSecureStorage에 저장

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 세션 전용 Secure Storage
/// iOS Keychain / Android EncryptedSharedPreferences 사용
class SessionSecureStorage {
  SessionSecureStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keySessionToken = 'syncflow_session_token';
  static const String _keySessionExpiresAt = 'syncflow_session_expires_at';
  static const String _keyUserId = 'syncflow_user_id';
  static const String _keyHasEverLoggedIn = 'syncflow_has_ever_logged_in';

  /// 세션 토큰 조회
  static Future<String?> getSessionToken() =>
      _storage.read(key: _keySessionToken);

  /// 세션 만료 시각 (ISO8601) 조회
  static Future<String?> getSessionExpiresAt() =>
      _storage.read(key: _keySessionExpiresAt);

  /// 사용자 ID 조회
  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _keyUserId);
    return v != null ? int.tryParse(v) : null;
  }

  /// 세션 저장 (로그인 성공 시)
  static Future<void> saveSession(String token, String expiresAt, {int? userId}) async {
    await _storage.write(key: _keySessionToken, value: token);
    await _storage.write(key: _keySessionExpiresAt, value: expiresAt);
    if (userId != null) {
      await _storage.write(key: _keyUserId, value: userId.toString());
    }
  }

  /// 로그아웃 시 세션 삭제
  static Future<void> clearSession() async {
    await _storage.delete(key: _keySessionToken);
    await _storage.delete(key: _keySessionExpiresAt);
    await _storage.delete(key: _keyUserId);
  }

  /// 한 번이라도 로그인에 성공한 적 있음 (온보딩 이원 화면 스킵용). 로그아웃 시에도 유지.
  static Future<bool> getHasEverLoggedIn() async {
    final v = await _storage.read(key: _keyHasEverLoggedIn);
    return v == '1' || v == 'true';
  }

  static Future<void> setHasEverLoggedIn(bool value) async {
    if (value) {
      await _storage.write(key: _keyHasEverLoggedIn, value: '1');
    } else {
      await _storage.delete(key: _keyHasEverLoggedIn);
    }
  }
}
