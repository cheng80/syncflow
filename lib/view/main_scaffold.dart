// main_scaffold.dart
// 메인 스캐폴드 - 홈 화면 표시

import 'package:flutter/material.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/view/home.dart';

/// 메인 스캐폴드 - 홈 화면
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.icon),
        title: Text(
          'SyncFlow',
          style: TextStyle(color: p.textPrimary, fontSize: ConfigUI.fontSizeAppBar),
        ),
      ),
      body: const Home(),
    );
  }
}
