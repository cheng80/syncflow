// config_ui.dart
// Flat + Minimalism + Soft UI 공통 설정 (접근성·일관성)
//
// 위젯에서 ConfigUI.xxx 로 참조합니다.
// 색상은 context.appTheme, 레이아웃/반경/애니메이션은 여기서 통일합니다.

import 'package:flutter/material.dart';

/// 앱 전역 UI 상수 (Soft UI 업그레이드 + 접근성)
class ConfigUI {
  ConfigUI._();

  // ─── 접근성 (Accessible) ─────────────────────────────────────────────
  /// 터치 영역 최소 크기 (iOS HIG / Material 권장 48dp)
  static const double minTouchTarget = 44.0;

  /// 포커스 링 두께 (키보드/스위치 포커스 가시성)
  static const double focusBorderWidth = 2.0;

  // ─── 모서리 (Soft UI - 둥근 모서리) ───────────────────────────────────
  static const double radiusCard = 12.0;
  static const double radiusSheet = 16.0;
  static const double radiusButton = 10.0;
  static const double radiusInput = 8.0;
  static const double radiusChip = 20.0;
  static const double radiusTagCell = 8.0;
  /// 히트맵 셀 (작은 정사각형)
  static const double radiusHeatmapCell = 2.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusCard);
  static BorderRadius get sheetRadius => BorderRadius.circular(radiusSheet);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusButton);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusInput);
  static BorderRadius get chipRadius => BorderRadius.circular(radiusChip);
  static BorderRadius get tagCellRadius =>
      BorderRadius.circular(radiusTagCell);
  static BorderRadius get heatmapCellRadius =>
      BorderRadius.circular(radiusHeatmapCell);

  // ─── 그림자·입체감 (Soft UI - 부드러운 그림자) ─────────────────────────
  /// 카드/리스트 아이템 (약한 그림자)
  static const double elevationCard = 1.0;
  /// 바텀시트 상단 등
  static const double elevationSheet = 2.0;
  /// 버튼 눌림 느낌
  static const double elevationButton = 0.5;
  /// 드래그 중 리스트 아이템
  static const double elevationDragProxy = 4.0;

  // ─── 애니메이션 ──────────────────────────────────────────────────────
  static const int durationShortMs = 150;
  static const int durationMediumMs = 250;
  static const Duration durationShort =
      Duration(milliseconds: durationShortMs);
  static const Duration durationMedium =
      Duration(milliseconds: durationMediumMs);
  static const Curve curveDefault = Curves.easeInOut;

  // ─── 간격 (일관된 여백) ──────────────────────────────────────────────
  /// 화면 좌우 패딩
  static const double screenPaddingH = 20.0;
  /// 작은 화면(<400px) 좌우 패딩
  static const double screenPaddingHCompact = 12.0;
  /// 카드/컨테이너 내부 패딩
  static const double paddingCard = 16.0;
  /// 빈 상태/로딩 등 여백
  static const double paddingEmptyState = 24.0;
  /// 리스트 아이템 좌측 여백 (홈 리스트)
  static const double listItemMarginLeft = 20.0;
  static const double listItemMarginRight = 8.0;
  static const double listItemMarginTop = 6.0;
  static const double listItemMarginBottom = 10.0;
  /// 시트/다이얼로그 내부 좌우
  static const double sheetPaddingH = 20.0;
  /// 시트 내 버튼 행 높이 (minTouchTarget 이상)
  static const double sheetButtonHeight = 50.0;
  /// 칩 내부 패딩
  static const double chipPaddingH = 16.0;
  static const double chipPaddingV = 6.0;
  /// 필터 칩 등 작은 칩 가로 패딩
  static const double chipPaddingHCompact = 10.0;
  /// 입력 필드 contentPadding
  static const double inputPaddingH = 12.0;
  static const double inputPaddingV = 8.0;

  // ─── 타이포 (선택 사용) ───────────────────────────────────────────────
  static const double fontSizeTitle = 24.0;
  static const double fontSizeAppBar = 20.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeLabel = 14.0;
  static const double fontSizeButton = 15.0;
  static const double fontSizeChip = 13.0;
  static const double fontSizeMeta = 12.0;
  static const double fontSizeCaption = 11.0;

  // ─── 습관 카드 그리드 (HabitItem 전용) ─────────────────────────────────
  static const int habitCardGridColumns = 6;
  static const double habitCardCellSizeMin = 36.0;
  static const double habitCardCellSizeMax = 52.0;
  static const double habitCardCellSpacing = 8.0;
}
