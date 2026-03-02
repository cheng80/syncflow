// card_tile.dart
// 카드 타일 위젯 (리스트용)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/widget/card_markdown_preview.dart';

/// 카드 타일 (보드 컬럼 내 카드 표시)
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    required this.onRefresh,
    this.onMove,
  });

  final CardItem card;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  /// 컬럼 간 이동 모드 진입 (null이면 이동 아이콘 미표시)
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Material(
      color: p.cardBackground,
      borderRadius: ConfigUI.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: ConfigUI.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(ConfigUI.paddingCard),
          decoration: BoxDecoration(
            borderRadius: ConfigUI.cardRadius,
            border: Border.all(color: p.divider, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: TextStyle(
                        fontSize: ConfigUI.fontSizeBody,
                        fontWeight: FontWeight.w500,
                        color: p.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (card.priority != 'medium')
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: card.priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (onMove != null) ...[
                    const SizedBox(width: 4),
                    Material(
                      color: p.divider.withValues(alpha: 0.3),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onMove!();
                        },
                        customBorder: const CircleBorder(),
                        child: Tooltip(
                          message: context.tr('moveCard'),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.swap_horiz, size: 18, color: p.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (card.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                // 카드 목록에서는 Markdown 원문이 아닌 요약 텍스트를 노출한다.
                Text(
                  markdownToPreviewSummary(card.description),
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeLabel,
                    color: p.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
