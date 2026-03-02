import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

String markdownToPreviewSummary(String raw) {
  final text = sanitizeMarkdown(raw)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_~#]'), '')
      .trim();

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.join('  ');
}

String sanitizeMarkdown(String raw) {
  var text = raw;
  // 금지: fenced code block
  text = text.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
  // 금지: inline code (backtick만 제거해 plain text로 유지)
  text = text.replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) => m.group(1) ?? '');
  // 금지: image syntax
  text = text.replaceAll(RegExp(r'!\[[^\]]*]\([^)]+\)'), '');
  // 금지: html tag
  text = text.replaceAll(RegExp(r'</?[^>]+>'), '');
  return text;
}

class CardMarkdownPreview extends StatelessWidget {
  const CardMarkdownPreview({
    super.key,
    required this.text,
    this.emptyText,
  });

  final String text;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final sanitized = sanitizeMarkdown(text).trim();
    if (sanitized.isEmpty) {
      return Text(
        emptyText ?? context.tr('descriptionEmpty'),
        style: TextStyle(
          fontSize: ConfigUI.fontSizeLabel,
          color: p.textSecondary,
          height: 1.4,
        ),
      );
    }

    final style = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        fontSize: ConfigUI.fontSizeLabel,
        color: p.textSecondary,
        height: 1.4,
      ),
      h1: TextStyle(
        fontSize: ConfigUI.fontSizeSubtitle,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      h2: TextStyle(
        fontSize: ConfigUI.fontSizeBody,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      ),
      a: TextStyle(
        color: p.primary,
        decoration: TextDecoration.underline,
      ),
      blockquote: TextStyle(
        color: p.textSecondary,
      ),
      listBullet: TextStyle(
        color: p.textSecondary,
      ),
      checkbox: TextStyle(
        color: p.textSecondary,
      ),
      code: TextStyle(
        color: p.textSecondary,
      ),
      codeblockDecoration: BoxDecoration(
        color: p.cardBackground,
        borderRadius: ConfigUI.inputRadius,
      ),
    );

    return MarkdownBody(
      data: sanitized,
      styleSheet: style,
      extensionSet: md.ExtensionSet.gitHubWeb,
      shrinkWrap: true,
      softLineBreak: true,
      selectable: false,
    );
  }
}
