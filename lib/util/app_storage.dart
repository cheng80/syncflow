// app_storage.dart
// GetStorage 기반 앱 설정 헬퍼

import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

/// AppStorage - 앱 설정을 저장/조회하는 정적 헬퍼
///
/// GetStorage 접근을 한 곳으로 모아 관리한다.
/// 추후 설정 항목이 늘어나면 여기에 키/메서드를 추가한다.
class AppStorage {
  static GetStorage get _storage => GetStorage();
  static const _uuid = Uuid();

  // ─── 백업/복구 (device_uuid, last_backup_at 등) ─────────────────
  static const String _keyDeviceUuid = 'device_uuid';
  static const String _keyLastBackupAt = 'last_backup_at';
  static const String _keyLastBackupAttemptAt = 'last_backup_attempt_at';
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyAutoBackupAnnounced = 'auto_backup_announced';
  static const String _keyCooldownMinutes = 'cooldown_minutes';

  /// device_uuid 조회 (없으면 null)
  static String? getDeviceUuid() => _storage.read<String>(_keyDeviceUuid);

  /// device_uuid 생성·저장 (최초 1회). 이미 있으면 그대로 반환
  static Future<String> ensureDeviceUuid() async {
    var uuid = getDeviceUuid();
    if (uuid == null || uuid.isEmpty) {
      uuid = _uuid.v4();
      await _storage.write(_keyDeviceUuid, uuid);
    }
    return uuid;
  }

  /// 마지막 백업 시각 (ISO8601 문자열)
  static String? getLastBackupAt() => _storage.read<String>(_keyLastBackupAt);

  static Future<void> saveLastBackupAt(DateTime dateTime) =>
      _storage.write(_keyLastBackupAt, dateTime.toIso8601String());

  /// 마지막 백업 시도 시각 (쿨다운 체크용)
  static String? getLastBackupAttemptAt() =>
      _storage.read<String>(_keyLastBackupAttemptAt);

  static Future<void> saveLastBackupAttemptAt(DateTime dateTime) =>
      _storage.write(_keyLastBackupAttemptAt, dateTime.toIso8601String());

  /// 마지막 백업 시도 초기화 (쿨다운 리셋, 테스트용)
  static Future<void> clearLastBackupAttemptAt() =>
      _storage.remove(_keyLastBackupAttemptAt);

  /// 자동 백업 ON/OFF (기본값 false)
  static bool getAutoBackupEnabled() =>
      _storage.read<bool>(_keyAutoBackupEnabled) ?? false;

  static Future<void> setAutoBackupEnabled(bool enabled) =>
      _storage.write(_keyAutoBackupEnabled, enabled);

  /// 자동 백업 고지 팝업 표시 여부 (1회만)
  static bool getAutoBackupAnnounced() =>
      _storage.read<bool>(_keyAutoBackupAnnounced) ?? false;

  static Future<void> setAutoBackupAnnounced(bool v) =>
      _storage.write(_keyAutoBackupAnnounced, v);

  /// 백업 쿨다운(분). 기본 1분 (테스트용, 프로덕션은 10분 권장)
  static int getCooldownMinutes() =>
      _storage.read<int>(_keyCooldownMinutes) ?? 1;

  static Future<void> setCooldownMinutes(int minutes) =>
      _storage.write(_keyCooldownMinutes, minutes);

  // ─── 테마 ─────────────────────────────────────
  static const String _keyTheme = 'theme_mode';

  /// 저장된 테마 모드 문자열 조회 (light / dark / system)
  static String? getThemeMode() => _storage.read<String>(_keyTheme);

  /// 테마 모드 저장
  static Future<void> saveThemeMode(String mode) =>
      _storage.write(_keyTheme, mode);

  // ─── 스토어 리뷰 (in_app_review) ─────────────────
  static const String _keyFirstLaunchDate = 'first_launch_date';
  static const String _keyHabitAchievedCount = 'habit_achieved_count';
  static const String _keyReviewRequested = 'review_requested';

  /// 첫 실행일 (ISO8601 문자열). 없으면 null → 최초 1회 저장
  static String? getFirstLaunchDate() =>
      _storage.read<String>(_keyFirstLaunchDate);

  /// 첫 실행일 저장 (앱 최초 실행 시 1회)
  static Future<void> saveFirstLaunchDate(DateTime date) =>
      _storage.write(_keyFirstLaunchDate, date.toIso8601String());

  /// 습관 달성 누적 횟수 (목표 달성 시 +1, 인앱 리뷰 조건용)
  static int getHabitAchievedCount() =>
      _storage.read<int>(_keyHabitAchievedCount) ?? 0;

  /// 습관 달성 횟수 증가
  static Future<void> incrementHabitAchievedCount() async {
    final n = getHabitAchievedCount() + 1;
    await _storage.write(_keyHabitAchievedCount, n);
  }

  /// 리뷰 요청 이미 했는지
  static bool getReviewRequested() =>
      _storage.read<bool>(_keyReviewRequested) ?? false;

  /// 리뷰 요청 완료 표시
  static Future<void> setReviewRequested() =>
      _storage.write(_keyReviewRequested, true);

  // ─── 튜토리얼 (showcaseview) ─────────────────────
  static const String _keyTutorialCompleted = 'tutorial_completed';

  /// 튜토리얼 완료/스킵 여부 (앱 최초 실행 시 false)
  static bool getTutorialCompleted() =>
      _storage.read<bool>(_keyTutorialCompleted) ?? false;

  /// 튜토리얼 완료 표시
  static Future<void> setTutorialCompleted() =>
      _storage.write(_keyTutorialCompleted, true);

  /// 튜토리얼 다시 보기용 초기화
  static Future<void> resetTutorialCompleted() =>
      _storage.write(_keyTutorialCompleted, false);

  /// 튜토리얼용 습관 생성 여부 (앱 최초 실행 시 1회, 추후 온보딩 연동)
  static const String _keyTutorialHabitCreated = 'tutorial_habit_created';

  static bool getTutorialHabitCreated() =>
      _storage.read<bool>(_keyTutorialHabitCreated) ?? false;

  static Future<void> setTutorialHabitCreated() =>
      _storage.write(_keyTutorialHabitCreated, true);

  // ─── 화면 꺼짐 방지 (wakelock_plus) ─────────────────
  static const String _keyWakelock = 'wakelock_enabled';

  /// 화면 꺼짐 방지 여부 (기본값 false)
  static bool getWakelockEnabled() =>
      _storage.read<bool>(_keyWakelock) ?? false;

  static Future<void> setWakelockEnabled(bool enabled) =>
      _storage.write(_keyWakelock, enabled);

  // ─── 미리 알림 (점심/저녁 푸시) ─────────────────
  static const String _keyPreReminder = 'pre_reminder_enabled';

  /// 미리 알림 ON/OFF (기본값 true)
  static bool getPreReminderEnabled() =>
      _storage.read<bool>(_keyPreReminder) ?? true;

  static Future<void> setPreReminderEnabled(bool enabled) =>
      _storage.write(_keyPreReminder, enabled);

  // ─── 알림 권한 요청 기록 ─────────────────────────
  static const String _keyNotificationPermissionRequested =
      'notification_permission_requested';

  /// 알림 권한을 이미 요청했는지 (최초 1회만 시스템 다이얼로그 표시)
  static bool getNotificationPermissionRequested() =>
      _storage.read<bool>(_keyNotificationPermissionRequested) ?? false;

  /// 알림 권한 요청 완료 기록
  static Future<void> setNotificationPermissionRequested() =>
      _storage.write(_keyNotificationPermissionRequested, true);

  // ─── 히트맵 테마 ─────────────────────────────────
  static const String _keyHeatmapTheme = 'heatmap_theme';

  /// 잔디 색상 테마 (github, ocean, sunset, lavender, mint, rose, monochrome)
  static String getHeatmapTheme() =>
      _storage.read<String>(_keyHeatmapTheme) ?? 'github';

  static Future<void> saveHeatmapTheme(String theme) =>
      _storage.write(_keyHeatmapTheme, theme);
}
