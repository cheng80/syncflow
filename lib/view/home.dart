// home.dart
// 홈 화면 (최소 구성)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

/// Home - 홈 화면
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SyncFlow',
            style: TextStyle(
              fontSize: ConfigUI.fontSizeAppBar,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('appTagline'),
            style: TextStyle(
              fontSize: 14,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
