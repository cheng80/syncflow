// tutorial_keys.dart
// ShowcaseView 튜토리얼용 GlobalKey 모음

import 'package:flutter/material.dart';

/// 튜토리얼 단계별 Showcase GlobalKey
class TutorialKeys {
  TutorialKeys();

  final habitCard = GlobalKey();
  final cellGrid = GlobalKey();
  final completeRow = GlobalKey();
  final addHabit = GlobalKey();
  final menu = GlobalKey();
  final analysisTab = GlobalKey();

  /// 메뉴(드로워) → 습관 카드 → 칸 그리드 → 완료 → +버튼 → 분석 탭
  List<GlobalKey> get all => [
        menu,
        habitCard,
        cellGrid,
        completeRow,
        addHabit,
        analysisTab,
      ];
}
