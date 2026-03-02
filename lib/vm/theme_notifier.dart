// theme_notifier.dart
// 테마 모드 상태 관리

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncflow/util/app_storage.dart';

/// 테마 모드 상태를 관리하는 Notifier
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    /// 저장된 테마 모드 불러오기
    final saved = AppStorage.getThemeMode();
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// 테마 모드 변경
  void setThemeMode(ThemeMode mode) {
    state = mode;
    _save(mode);
  }

  /// 테마 토글 (라이트 ↔ 다크)
  /// 시스템 모드인 경우 라이트로 전환
  void toggleTheme() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }

  /// 현재 다크 모드인지 확인
  bool isDarkMode(BuildContext context) {
    if (state == ThemeMode.dark) return true;
    if (state == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  void _save(ThemeMode mode) {
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    AppStorage.saveThemeMode(str);
  }
}

/// 테마 Notifier Provider
final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
