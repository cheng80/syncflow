// app_drawer.dart
// 앱 사이드 메뉴 (설정)
//
// [구성] 다크 모드, 화면 꺼짐 방지, 언어, 평점 남기기, 튜토리얼 다시 보기, 로그아웃, 회원 탈퇴
// [참고] habit_app/lib/view/app_drawer.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/service/in_app_review_service.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/common_util.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/sheet_util.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/vm/board_list_notifier.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/vm/theme_notifier.dart';
import 'package:syncflow/vm/wakelock_notifier.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:syncflow/util/tutorial_keys.dart';
import 'package:syncflow/widget/language_picker_sheet.dart';

/// AppDrawer - 설정 및 부가 기능
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    this.tutorialKeys,
    this.onReplayTutorial,
  });

  /// ShowcaseView 튜토리얼용 키 (MainScaffold에서 전달)
  final TutorialKeys? tutorialKeys;

  /// 튜토리얼 다시 보기 콜백 (null이면 "준비 중" 스낵바)
  final VoidCallback? onReplayTutorial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.appTheme;
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Drawer(
      backgroundColor: p.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuHeader(context, ref, p),
            Divider(color: p.divider, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ConfigUI.screenPaddingH,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('darkMode'),
                          style: TextStyle(color: p.textPrimary, fontSize: 16),
                        ),
                        Switch(
                          value: isDark,
                          activeThumbColor: p.chipSelectedBg,
                          activeTrackColor: p.chipUnselectedBg,
                          inactiveThumbColor: p.textMeta,
                          inactiveTrackColor: p.chipUnselectedBg,
                          onChanged: (_) {
                            HapticFeedback.mediumImpact();
                            ref.read(themeNotifierProvider.notifier).toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ConfigUI.screenPaddingH,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('screenWakeLock'),
                          style: TextStyle(color: p.textPrimary, fontSize: 16),
                        ),
                        Switch(
                          value: ref.watch(wakelockNotifierProvider),
                          activeThumbColor: p.chipSelectedBg,
                          activeTrackColor: p.chipUnselectedBg,
                          inactiveThumbColor: p.textMeta,
                          inactiveTrackColor: p.chipUnselectedBg,
                          onChanged: (_) {
                            HapticFeedback.mediumImpact();
                            ref.read(wakelockNotifierProvider.notifier).toggle();
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(color: p.divider, height: 1),
                  ListTile(
                    leading: Icon(Icons.language, color: p.icon),
                    title: Text(
                      context.tr('language'),
                      style: TextStyle(color: p.textPrimary, fontSize: 16),
                    ),
                    trailing: Icon(Icons.chevron_right, color: p.textSecondary),
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 220));
                      if (!context.mounted) return;
                      final ctx = rootNavigatorKey.currentContext ?? context;
                      if (ctx.mounted) showLanguagePickerSheet(ctx);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.star_outline, color: p.icon),
                    title: Text(
                      context.tr('rateApp'),
                      style: TextStyle(color: p.textPrimary, fontSize: 16),
                    ),
                    trailing: Icon(Icons.open_in_new, color: p.textSecondary, size: 20),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await InAppReviewService().openStoreListing();
                      if (context.mounted && !ok) {
                        showCommonSnackBar(
                          context,
                          message: context.tr('rateAppUnavailable'),
                        );
                      }
                    },
                  ),
                  _buildTutorialReplayTile(context, p),
                  Divider(color: p.divider, height: 1),
                  ListTile(
                    leading: Icon(Icons.logout, color: p.icon),
                    title: Text(
                      context.tr('logout'),
                      style: TextStyle(color: p.textPrimary, fontSize: 16),
                    ),
                    trailing: Icon(Icons.chevron_right, color: p.textSecondary),
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(sessionNotifierProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
            Divider(color: p.divider, height: 1),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: p.accent, size: 20),
                title: Text(
                  context.tr('deleteAccount'),
                style: TextStyle(color: p.textMeta, fontSize: 13),
              ),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(ctx.tr('deleteAccount')),
                    content: Text(ctx.tr('deleteAccountConfirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(ctx.tr('cancel')),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(ctx.tr('withdraw')),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref.read(sessionNotifierProvider.notifier).deleteAccount();
                } on ApiException catch (e) {
                  final ctx = rootNavigatorKey.currentContext ?? context;
                  if (ctx.mounted) {
                    showCommonSnackBar(ctx, message: e.message);
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ConfigUI.screenPaddingH, 12, ConfigUI.screenPaddingH, 16,
              ),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, snapshot) {
                  final v = snapshot.data;
                  final text = v != null
                      ? '${context.tr('appVersion')} ${v.version}+${v.buildNumber}'
                      : context.tr('appVersion');
                  return Text(
                    text,
                    style: TextStyle(
                      color: p.textMeta,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialReplayTile(BuildContext context, AppThemeColorsHelper p) {
    final tile = ListTile(
      leading: Icon(Icons.school_outlined, color: p.icon),
      title: Text(
        context.tr('tutorial_replay'),
        style: TextStyle(color: p.textPrimary, fontSize: 16),
      ),
      trailing: Icon(Icons.chevron_right, color: p.textSecondary),
      onTap: () {
        Navigator.pop(context);
        if (onReplayTutorial != null) {
          AppStorage.resetTutorialCompleted();
          onReplayTutorial!();
        } else {
          final ctx = rootNavigatorKey.currentContext ?? context;
          if (ctx.mounted) {
            showOverlaySnackBar(
              ctx,
              message: context.tr('tutorialPreparing'),
            );
          }
        }
      },
    );
    if (tutorialKeys != null) {
      return Showcase(
        key: tutorialKeys!.drawerTutorial,
        description: context.tr('tutorial_step_1'),
        tooltipBackgroundColor: p.sheetBackground,
        textColor: p.textOnSheet,
        tooltipBorderRadius: ConfigUI.cardRadius,
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildMenuHeader(BuildContext context, WidgetRef ref, AppThemeColorsHelper p) {
    return GestureDetector(
      onLongPress: kReleaseMode
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _showSecretMenu(context, ref, p);
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ConfigUI.screenPaddingH, 24, ConfigUI.screenPaddingH, 16,
        ),
        child: Row(
          children: [
            Icon(Icons.settings, color: p.icon, size: 28),
            const SizedBox(width: 12),
            Text(
              context.tr('settings'),
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecretMenu(BuildContext context, WidgetRef ref, AppThemeColorsHelper p) {
    showModalBottomSheet(
      context: context,
      shape: defaultSheetShape,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('devMenu'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeSubtitle,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.info_outline, color: p.icon),
                title: Text(context.tr('versionInfo'), style: TextStyle(color: p.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showVersionInfo(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.add_task, color: p.icon),
                title: Text(context.tr('devMenuDummyData'), style: TextStyle(color: p.textPrimary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _createTestBoardDummyData(context, ref);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createTestBoardDummyData(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionNotifierProvider).value;
    if (session?.sessionToken == null) {
      if (context.mounted) {
        showCommonSnackBar(context, message: context.tr('sessionExpired'));
      }
      return;
    }

    try {
      showOverlaySnackBar(context, message: context.tr('devMenuDummyDataCreating'));
      final board = await ref.read(boardListNotifierProvider.notifier).ensureTutorialBoardWithSamples(
        cardsPerColumn: 3,
      );
      if (board == null) {
        if (context.mounted) {
          showCommonSnackBar(context, message: context.tr('devMenuDummyDataFailed'));
        }
        return;
      }
      await ref.read(boardListNotifierProvider.notifier).refresh();
      if (context.mounted) {
        showCommonSnackBar(context, message: context.tr('devMenuDummyDataDone'));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showCommonSnackBar(context, message: e.message);
      }
    } catch (_) {
      if (context.mounted) {
        showCommonSnackBar(context, message: context.tr('devMenuDummyDataFailed'));
      }
    }
  }

  void _showVersionInfo(BuildContext context) {
    PackageInfo.fromPlatform().then((info) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('versionInfo')),
          content: Text(
            '${info.appName}\n${info.version}+${info.buildNumber}\n${info.packageName}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      );
    });
  }
}
