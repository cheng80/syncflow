import 'package:flutter/material.dart';

/// 앱 전용 테마 색상 (Brightness 기반)
///
/// Theme.of(context).brightness로 라이트/다크 판별.
/// ThemeExtension 없이 단순 구현.
///
/// 사용 예시:
/// ```dart
/// Container(color: AppThemeColors.background(context))
/// Text('제목', style: TextStyle(color: AppThemeColors.textPrimary(context)))
/// final p = context.appTheme;
/// Container(color: p.background)
/// ```
class AppThemeColors {
  AppThemeColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ThemeData 정의용 상수 (main.dart 등에서 사용)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF1A1A1A);

  /// 전체 배경 색
  static Color background(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5);

  /// 카드/패널 배경 색
  static Color cardBackground(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF242424)
          : Colors.white;

  /// 시트 배경 색
  static Color sheetBackground(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF2C2C2C)
          : Colors.white;

  /// 주요 포인트 색
  static Color primary(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFF1976D2);

  /// 보조 포인트 색
  static Color accent(BuildContext context) => Colors.red;

  /// 기본 텍스트 색
  static Color textPrimary(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFF212121);

  /// 보조 텍스트 색
  static Color textSecondary(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF737373)
          : const Color(0xFF616161);

  /// 메타 텍스트 색 (날짜, 태그 이름)
  static Color textMeta(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFFD7D7D7)
          : const Color(0xFF616161);

  /// Primary 배경 위 텍스트 색
  static Color textOnPrimary(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF1A1A1A)
          : Colors.white;

  /// BottomSheet 위 텍스트 색
  static Color textOnSheet(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFFF0F0F0)
          : const Color(0xFF212121);

  /// 구분선 색
  static Color divider(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF3C3C3C)
          : const Color(0xFFE0E0E0);

  /// 아이콘 기본 색
  static Color icon(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFF212121);

  /// BottomSheet 위 아이콘 색
  static Color iconOnSheet(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFFB4B4B4)
          : const Color(0xFF424242);

  /// 칩 선택 배경 색
  static Color chipSelectedBg(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFF212121);

  /// 칩 선택 텍스트 색
  static Color chipSelectedText(BuildContext context) =>
      _isDark(context)
          ? Colors.black
          : Colors.white;

  /// 칩 비선택 배경 색
  static Color chipUnselectedBg(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF323232)
          : const Color(0xFFE0E0E0);

  /// 칩 비선택 텍스트 색
  static Color chipUnselectedText(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFF212121);

  /// 드롭다운 배경 색
  static Color dropdownBg(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF1A1A1A)
          : Colors.white;

  /// 검색 필드 배경 색
  static Color searchFieldBg(BuildContext context) =>
      _isDark(context)
          ? Colors.white
          : const Color(0xFFE0E0E0);

  /// 검색 필드 텍스트 색
  static Color searchFieldText(BuildContext context) =>
      _isDark(context)
          ? Colors.black
          : const Color(0xFF212121);

  /// 검색 필드 힌트 색
  static Color searchFieldHint(BuildContext context) =>
      _isDark(context)
          ? const Color(0xFF787878)
          : const Color(0xFF757575);

  /// 마감일/알람 아이콘 색
  static Color alarmAccent(BuildContext context) =>
      const Color(0xFFFFB300);
}

/// BuildContext 확장 - context.appTheme.xxx 로 접근
extension AppThemeContext on BuildContext {
  AppThemeColorsHelper get appTheme => AppThemeColorsHelper(this);
}

/// context.appTheme 접근용 헬퍼
class AppThemeColorsHelper {
  final BuildContext _context;

  AppThemeColorsHelper(this._context);

  Color get background => AppThemeColors.background(_context);
  Color get cardBackground => AppThemeColors.cardBackground(_context);
  Color get sheetBackground => AppThemeColors.sheetBackground(_context);
  Color get primary => AppThemeColors.primary(_context);
  Color get accent => AppThemeColors.accent(_context);
  Color get textPrimary => AppThemeColors.textPrimary(_context);
  Color get textSecondary => AppThemeColors.textSecondary(_context);
  Color get textMeta => AppThemeColors.textMeta(_context);
  Color get textOnPrimary => AppThemeColors.textOnPrimary(_context);
  Color get textOnSheet => AppThemeColors.textOnSheet(_context);
  Color get divider => AppThemeColors.divider(_context);
  Color get icon => AppThemeColors.icon(_context);
  Color get iconOnSheet => AppThemeColors.iconOnSheet(_context);
  Color get chipSelectedBg => AppThemeColors.chipSelectedBg(_context);
  Color get chipSelectedText => AppThemeColors.chipSelectedText(_context);
  Color get chipUnselectedBg => AppThemeColors.chipUnselectedBg(_context);
  Color get chipUnselectedText => AppThemeColors.chipUnselectedText(_context);
  Color get dropdownBg => AppThemeColors.dropdownBg(_context);
  Color get searchFieldBg => AppThemeColors.searchFieldBg(_context);
  Color get searchFieldText => AppThemeColors.searchFieldText(_context);
  Color get searchFieldHint => AppThemeColors.searchFieldHint(_context);
  Color get alarmAccent => AppThemeColors.alarmAccent(_context);
}
