import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

class AppDrawerMenuHeader extends StatelessWidget {
  const AppDrawerMenuHeader({
    super.key,
    required this.onLongPress,
  });

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ConfigUI.screenPaddingH,
          24,
          ConfigUI.screenPaddingH,
          16,
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
}

class AppDrawerSwitchRow extends StatelessWidget {
  const AppDrawerSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ConfigUI.screenPaddingH,
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: p.textPrimary, fontSize: 16),
          ),
          Switch(
            value: value,
            activeThumbColor: p.chipSelectedBg,
            activeTrackColor: p.chipUnselectedBg,
            inactiveThumbColor: p.textMeta,
            inactiveTrackColor: p.chipUnselectedBg,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class AppDrawerTutorialReplayTile extends StatelessWidget {
  const AppDrawerTutorialReplayTile({
    super.key,
    required this.tutorialShowcaseKey,
    required this.onTap,
  });

  final GlobalKey? tutorialShowcaseKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final tile = ListTile(
      leading: Icon(Icons.school_outlined, color: p.icon),
      title: Text(
        context.tr('tutorial_replay'),
        style: TextStyle(color: p.textPrimary, fontSize: 16),
      ),
      trailing: Icon(Icons.chevron_right, color: p.textSecondary),
      onTap: onTap,
    );
    if (tutorialShowcaseKey == null) return tile;
    return Showcase(
      key: tutorialShowcaseKey!,
      description: context.tr('tutorial_step_1'),
      tooltipBackgroundColor: p.sheetBackground,
      textColor: p.textOnSheet,
      tooltipBorderRadius: ConfigUI.cardRadius,
      child: tile,
    );
  }
}

class AppDrawerDeleteAccountTile extends StatelessWidget {
  const AppDrawerDeleteAccountTile({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return ListTile(
      leading: Icon(Icons.person_remove_outlined, color: p.accent, size: 20),
      title: Text(
        context.tr('deleteAccount'),
        style: TextStyle(color: p.textMeta, fontSize: 13),
      ),
      onTap: onTap,
    );
  }
}

class AppDrawerVersionFooter extends StatelessWidget {
  const AppDrawerVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ConfigUI.screenPaddingH,
        12,
        ConfigUI.screenPaddingH,
        16,
      ),
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
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
    );
  }
}
