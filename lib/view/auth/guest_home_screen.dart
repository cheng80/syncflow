// guest_home_screen.dart
// 게스트 모드 홈 (M1 플레이스홀더). M2에서 로컬 보드 목록·튜토리얼 연결.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/vm/app_flow_providers.dart';
import 'package:syncflow/widget/language_picker_sheet.dart';

class GuestHomeScreen extends ConsumerWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.appTheme;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('guestModeTitle'),
          style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: p.icon),
        actions: [
          IconButton(
            icon: Icon(Icons.language, color: p.icon),
            onPressed: () => showLanguagePickerSheet(context),
            tooltip: context.tr('language'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.edit_note_outlined, size: 64, color: p.textSecondary),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('guestHomeBody'),
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: ConfigUI.fontSizeBody,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      await AppStorage.setGuestBrowsingActive(false);
                      ref.read(guestBrowsingProvider.notifier).state = false;
                      ref.read(showLoginFromWelcomeProvider.notifier).state =
                          true;
                    },
                    child: Text(context.tr('guestHomeSignIn')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
