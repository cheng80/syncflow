// app_storage.dart
// GetStorage 기반 앱 설정 헬퍼

import 'package:get_storage/get_storage.dart';

/// AppStorage - 앱 설정을 저장/조회하는 정적 헬퍼
///
/// SyncFlow 전용. 세션 토큰, 테마 등 설정을 한 곳에서 관리한다.
class AppStorage {
  static GetStorage get _storage => GetStorage();

  // ─── 세션 ─────────────────────────────────────
  // 세션은 SessionSecureStorage 사용 (lib/util/session_secure_storage.dart)

  // ─── 재설치 감지 (iOS Keychain은 앱 삭제 후에도 유지됨) ─────────────────
  static const String _keyAppHasLaunched = 'app_has_launched';

  /// 앱이 한 번이라도 실행된 적 있는지 (GetStorage는 앱 삭제 시 삭제됨)
  static bool get hasAppLaunchedBefore =>
      _storage.read<bool>(_keyAppHasLaunched) ?? false;

  static Future<void> setAppHasLaunched() =>
      _storage.write(_keyAppHasLaunched, true);

  // ─── 테마 ─────────────────────────────────────
  static const String _keyTheme = 'theme_mode';

  /// 저장된 테마 모드 문자열 조회 (light / dark / system)
  static String? getThemeMode() => _storage.read<String>(_keyTheme);

  /// 테마 모드 저장
  static Future<void> saveThemeMode(String mode) =>
      _storage.write(_keyTheme, mode);

  // ─── 스토어 리뷰 (in_app_review) ─────────────────
  static const String _keyFirstLaunchDate = 'first_launch_date';
  static const String _keyReviewRequested = 'review_requested';

  /// 첫 실행일 (ISO8601 문자열). 없으면 null → 최초 1회 저장
  static String? getFirstLaunchDate() =>
      _storage.read<String>(_keyFirstLaunchDate);

  /// 첫 실행일 저장 (앱 최초 실행 시 1회)
  static Future<void> saveFirstLaunchDate(DateTime date) =>
      _storage.write(_keyFirstLaunchDate, date.toIso8601String());

  /// 리뷰 요청 이미 했는지
  static bool getReviewRequested() =>
      _storage.read<bool>(_keyReviewRequested) ?? false;

  /// 리뷰 요청 완료 표시
  static Future<void> setReviewRequested() =>
      _storage.write(_keyReviewRequested, true);

  // ─── 화면 꺼짐 방지 (wakelock_plus) ─────────────────
  static const String _keyWakelock = 'wakelock_enabled';

  /// 화면 꺼짐 방지 여부 (기본값 false)
  static bool getWakelockEnabled() =>
      _storage.read<bool>(_keyWakelock) ?? false;

  static Future<void> setWakelockEnabled(bool enabled) =>
      _storage.write(_keyWakelock, enabled);

  // ─── 튜토리얼 (ShowcaseView) ─────────────────
  static const String _keyTutorialCompleted = 'tutorial_completed';

  /// 튜토리얼 완료 여부
  static bool getTutorialCompleted() =>
      _storage.read<bool>(_keyTutorialCompleted) ?? false;

  /// 튜토리얼 완료 저장
  static Future<void> setTutorialCompleted() =>
      _storage.write(_keyTutorialCompleted, true);

  /// 튜토리얼 완료 초기화 (다시 보기용)
  static Future<void> resetTutorialCompleted() =>
      _storage.write(_keyTutorialCompleted, false);

  // ─── 튜토리얼 보드 (최초 설치 시 자동 생성) ─────────────────
  static const String _keyTutorialBoardCreated = 'tutorial_board_created';

  /// 튜토리얼 보드 생성 여부 (최초 1회 생성 후 true)
  static bool get hasTutorialBoardCreated =>
      _storage.read<bool>(_keyTutorialBoardCreated) ?? false;

  static Future<void> setTutorialBoardCreated() =>
      _storage.write(_keyTutorialBoardCreated, true);

  /// 실패 시 재시도용
  static Future<void> resetTutorialBoardCreated() =>
      _storage.write(_keyTutorialBoardCreated, false);
}
