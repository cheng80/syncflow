import 'package:flutter/material.dart';
import 'package:syncflow/model/board.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

class BoardDetailHeader extends StatelessWidget {
  const BoardDetailHeader({
    super.key,
    required this.title,
    required this.isOwner,
    required this.onBack,
    this.menuButton,
    required this.presenceRowChildren,
  });

  final String title;
  final bool isOwner;
  final VoidCallback onBack;
  final Widget? menuButton;
  final List<Widget> presenceRowChildren;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: ConfigUI.fontSizeAppBar,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (isOwner && menuButton != null)
                menuButton!
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: presenceRowChildren,
          ),
        ],
      ),
    );
  }
}

class BoardDetailColumnTabsBar extends StatelessWidget {
  const BoardDetailColumnTabsBar({
    super.key,
    required this.columns,
    required this.currentIndex,
    required this.onTapColumn,
    required this.isOwner,
    this.manageButton,
    this.filterRow,
  });

  final List<ColumnItem> columns;
  final int currentIndex;
  final ValueChanged<int> onTapColumn;
  final bool isOwner;
  final Widget? manageButton;

  /// 아랫줄 필터 (맨션만 보기, 완료/미완료 등). null이면 미표시.
  final Widget? filterRow;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ConfigUI.screenPaddingH,
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(columns.length, (index) {
                      return _ColumnTab(
                        label: columns[index].title,
                        isSelected: currentIndex == index,
                        onTap: () => onTapColumn(index),
                      );
                    }),
                  ),
                ),
              ),
              if (isOwner && manageButton != null) ...[
                const SizedBox(width: 8),
                manageButton!,
              ],
            ],
          ),
          if (filterRow != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: ConfigUI.cardRadius,
                border: Border.all(color: p.divider),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filterRow!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnTab extends StatelessWidget {
  const _ColumnTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ConfigUI.durationShort,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? p.primary.withValues(alpha: 0.2)
                : p.cardBackground,
            borderRadius: ConfigUI.chipRadius,
            border: Border.all(
              color: isSelected
                  ? p.primary
                  : p.textSecondary.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? p.primary : p.textSecondary,
              fontSize: ConfigUI.fontSizeLabel,
            ),
          ),
        ),
      ),
    );
  }
}
