// tutorial_keys.dart
// ShowcaseView 튜토리얼용 GlobalKey 모음 (SyncFlow 전용)

import 'package:flutter/material.dart';

/// 튜토리얼 단계별 Showcase GlobalKey
/// MainScaffold에서 생성 후 BoardListScreen, AppDrawer에 전달
class TutorialKeys {
  TutorialKeys()
      : drawerTutorial = GlobalKey(),
        menu = GlobalKey(),
        join = GlobalKey(),
        create = GlobalKey(),
        filter = GlobalKey();

  final GlobalKey drawerTutorial;
  final GlobalKey menu;
  final GlobalKey join;
  final GlobalKey create;
  final GlobalKey filter;

  /// 단계 순서 (Drawer 열린 상태 → Drawer 닫힌 후 메인 화면)
  List<GlobalKey> get all => [drawerTutorial, menu, join, create, filter];
}
