// main_scaffold.dart
// 메인 스캐폴드 - 홈 화면 표시

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/view/board_list_screen.dart';
import 'package:syncflow/vm/session_notifier.dart';

/// 메인 스캐폴드 - 홈 화면
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(sessionNotifierProvider.notifier).logout();
            },
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: const BoardListScreen(),
    );
  }
}
