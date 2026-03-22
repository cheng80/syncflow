// welcome_screen.dart
// 신규 사용자: 게스트로 시작 / 이메일 로그인 이원 진입 (M1)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/vm/app_flow_providers.dart';
import 'package:syncflow/widget/language_picker_sheet.dart';

/// 최초 설치 등: 이메일 로그인 이력이 없을 때만 표시.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.appTheme;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
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
                  Text(
                    context.tr('appName'),
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: ConfigUI.fontSizeTitle,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('appTagline'),
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: ConfigUI.fontSizeBody,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    context.tr('welcomeSubtitle'),
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: ConfigUI.fontSizeLabel,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      await AppStorage.setGuestBrowsingActive(true);
                      ref.read(guestBrowsingProvider.notifier).state = true;
                    },
                    child: Text(context.tr('continueAsGuest')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(showLoginFromWelcomeProvider.notifier).state =
                          true;
                    },
                    child: Text(context.tr('signInWithEmail')),
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
