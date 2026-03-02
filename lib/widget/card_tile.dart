// card_tile.dart
// 카드 타일 위젯 (리스트용)

import 'package:flutter/material.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

/// 카드 타일 (보드 컬럼 내 카드 표시)
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    required this.onRefresh,
  });

  final CardItem card;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

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
                      maxLines: 2,
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
                ],
              ),
              if (card.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.description,
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
