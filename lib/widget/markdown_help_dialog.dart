import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/widget/card_markdown_preview.dart';

Future<void> showMarkdownHelpDialog(BuildContext context) async {
  final p = context.appTheme;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('markdownGuide')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.tr('mdSupportedSyntax'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeLabel,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(ctx.tr('mdBoldItalic'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdHeadings'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdList'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdChecklist'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdLink'), style: TextStyle(color: p.textSecondary)),
              const SizedBox(height: 12),
              Text(
                ctx.tr('mdForbiddenSyntax'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeLabel,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(ctx.tr('mdCodeBlock'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdImage'), style: TextStyle(color: p.textSecondary)),
              Text(ctx.tr('mdHtmlTag'), style: TextStyle(color: p.textSecondary)),
              const SizedBox(height: 16),
              Text(
                ctx.tr('mdExampleSource'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeLabel,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.cardBackground,
                  borderRadius: ConfigUI.inputRadius,
                  border: Border.all(color: p.divider),
                ),
                child: SelectableText(
                  ctx.tr('mdExample').trim(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ctx.tr('preview'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeLabel,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.cardBackground,
                  borderRadius: ConfigUI.inputRadius,
                  border: Border.all(color: p.divider),
                ),
                child: CardMarkdownPreview(text: ctx.tr('mdExample')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.tr('close')),
        ),
      ],
    ),
  );
}
