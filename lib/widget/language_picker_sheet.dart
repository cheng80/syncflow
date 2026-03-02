// language_picker_sheet.dart
// 다국어 선택 바텀시트

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/sheet_util.dart';

/// 다국어 선택 바텀시트 표시
void showLanguagePickerSheet(BuildContext context) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  showModalBottomSheet(
    context: rootContext,
    useRootNavigator: true,
    shape: defaultSheetShape,
    builder: (ctx) {
      final p = ctx.appTheme;
      return SafeArea(
        child: Container(
          color: p.sheetBackground,
          padding: const EdgeInsets.symmetric(vertical: ConfigUI.paddingCard),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ConfigUI.sheetPaddingH,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ctx.tr('language'),
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: ConfigUI.fontSizeSubtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _LangTile(locale: const Locale('ko'), label: ctx.tr('langKo')),
              _LangTile(locale: const Locale('en'), label: ctx.tr('langEn')),
              _LangTile(locale: const Locale('ja'), label: ctx.tr('langJa')),
              _LangTile(
                locale: const Locale('zh', 'CN'),
                label: ctx.tr('langZhCN'),
              ),
              _LangTile(
                locale: const Locale('zh', 'TW'),
                label: ctx.tr('langZhTW'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LangTile extends StatelessWidget {
  final Locale locale;
  final String label;

  const _LangTile({
    required this.locale,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final isSelected = context.locale == locale;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? p.primary : p.icon,
        size: 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: p.textOnSheet,
          fontSize: ConfigUI.fontSizeBody,
        ),
      ),
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
