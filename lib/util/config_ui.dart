// config_ui.dart
// Neo-Brutalism + 접근성 공통 설정
//
// 위젯에서 ConfigUI.xxx 로 참조합니다.
// 색상은 context.appTheme, 레이아웃/반경/애니메이션은 여기서 통일합니다.

import 'package:flutter/material.dart';

/// 앱 전역 UI 상수 (Neo-Brutalism 컨셉)
class ConfigUI {
  ConfigUI._();

  // ─── 접근성 (Accessible) ─────────────────────────────────────────────
  /// 터치 영역 최소 크기 (iOS HIG / Material 권장 48dp)
  static const double minTouchTarget = 44.0;

  /// 포커스 링 두께 (키보드/스위치 포커스 가시성)
  static const double focusBorderWidth = 2.0;

  /// 태블릿 레이아웃 기준 (shortestSide)
  static const double tabletBreakpoint = 600.0;

  // ─── Neo-Brutalism: 두꺼운 보더·오프셋 쉐도우 ─────────────────────────
  /// 카드/버튼/입력 보더 두께 (2~3px)
  static const double borderWidthBrutal = 3.0;
  /// 오프셋 쉐도우 거리 (6px)
  static const double shadowOffsetBrutal = 6.0;

  // ─── 모서리 (Neo-Brutalism: 둥글지 않음 또는 약한 radius) ─────────────
  static const double radiusCard = 6.0;
  static const double radiusSheet = 8.0;
  static const double radiusButton = 6.0;
  static const double radiusInput = 6.0;
  static const double radiusChip = 6.0;
  static const double radiusTagCell = 4.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusCard);
  static BorderRadius get sheetRadius => BorderRadius.circular(radiusSheet);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusButton);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusInput);
  static BorderRadius get chipRadius => BorderRadius.circular(radiusChip);
  static BorderRadius get tagCellRadius =>
      BorderRadius.circular(radiusTagCell);

  // ─── Neo-Brutalism: 오프셋 쉐도우 (그림자 대신 명확한 오프셋) ─────────
  /// 카드용 오프셋 박스쉐도우 (6px x 6px 검정)
  static List<BoxShadow> shadowOffsetBrutalCard(Color color) => [
    BoxShadow(
      color: color,
      offset: const Offset(ConfigUI.shadowOffsetBrutal, ConfigUI.shadowOffsetBrutal),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
  /// 드래그 중 카드 (강조)
  static const double elevationCard = 0;
  /// 바텀시트 상단 등
  static const double elevationSheet = 2.0;
  /// 버튼 눌림 느낌
  static const double elevationButton = 0.5;
  /// 드래그 중 리스트 아이템
  static const double elevationDragProxy = 4.0;

  // ─── 애니메이션 (Neo-Brutalism: 빠르고 즉각적) ─────────────────────────
  static const int durationShortMs = 200;
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
  /// Neo-Brutalism: 두꺼운 보더 보정 - 컬럼 헤더~카드 간격 (보더 두꺼워져서 간격 확대)
  static const double gapColumnHeaderToCards = 12.0;
  /// Neo-Brutalism: 두꺼운 보더 보정 - 카드 간 간격 (보더 두꺼워져서 간격 확대)
  static const double gapBetweenCards = 12.0;
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

  // ─── 보드 리스트 화면 공통 규격 ───────────────────────────────────────
  static const double boardListActionButtonHeightPhone = minTouchTarget;
  static const double boardListActionButtonHeightTablet = 52.0;
  static const double boardListActionButtonPaddingHPhone = 16.0;
  static const double boardListActionButtonPaddingVPhone = 10.0;
  static const double boardListActionButtonPaddingHTablet = 18.0;
  static const double boardListActionButtonPaddingVTablet = 12.0;
  static const double boardListActionButtonGap = 8.0;
  static const double boardListFilterChipGap = 8.0;

  static bool isTabletLayout(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;

  static double boardListActionButtonHeight(BuildContext context) =>
      isTabletLayout(context)
          ? boardListActionButtonHeightTablet
          : boardListActionButtonHeightPhone;

  static EdgeInsets boardListActionButtonPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: isTabletLayout(context)
            ? boardListActionButtonPaddingHTablet
            : boardListActionButtonPaddingHPhone,
        vertical: isTabletLayout(context)
            ? boardListActionButtonPaddingVTablet
            : boardListActionButtonPaddingVPhone,
      );

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

  // ─── 카드 입력 제한 ───────────────────────────────────────────────────
  static const int cardTitleMaxLength = 80;
  static const int cardDescriptionMaxLength = 4000;
  static const int cardDescriptionMaxLines = 100;

  // ─── 보드 상세: 카드 생성 시트 규격 ───────────────────────────────────
  /// 새 카드 생성 바텀시트 최대 높이 비율 (화면 대비)
  static const double addCardSheetMaxHeightFactor = 0.82;
  /// 새 카드 설명 입력 기본 표시 줄 수
  static const int addCardDescriptionMinLines = 8;
  /// 새 카드 설명 입력 최대 표시 줄 수 (내부 스크롤 시작 전)
  static const int addCardDescriptionMaxVisibleLines = 14;
}
