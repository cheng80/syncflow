import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

class BoardListActionsRow extends StatelessWidget {
  const BoardListActionsRow({
    super.key,
    this.joinShowcaseKey,
    this.createShowcaseKey,
    required this.joinDescription,
    required this.createDescription,
    required this.joinLabel,
    required this.createLabel,
    required this.onJoin,
    required this.onCreate,
  });

  final GlobalKey? joinShowcaseKey;
  final GlobalKey? createShowcaseKey;
  final String joinDescription;
  final String createDescription;
  final String joinLabel;
  final String createLabel;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  Widget _wrapShowcase({
    required BuildContext context,
    GlobalKey? key,
    required String description,
    required Widget child,
  }) {
    if (key == null) return child;
    final p = context.appTheme;
    return Showcase(
      key: key,
      description: description,
      tooltipBackgroundColor: p.sheetBackground,
      textColor: p.textOnSheet,
      tooltipBorderRadius: ConfigUI.cardRadius,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionButtonHeight = ConfigUI.boardListActionButtonHeight(context);
    final actionButtonPadding = ConfigUI.boardListActionButtonPadding(context);

    return Row(
      children: [
        const Spacer(),
        _wrapShowcase(
          context: context,
          key: joinShowcaseKey,
          description: joinDescription,
          child: OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.group_add, size: 20),
            label: Text(joinLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, actionButtonHeight),
              padding: actionButtonPadding,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
        const SizedBox(width: ConfigUI.boardListActionButtonGap),
        _wrapShowcase(
          context: context,
          key: createShowcaseKey,
          description: createDescription,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 20),
            label: Text(createLabel),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, actionButtonHeight),
              padding: actionButtonPadding,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ],
    );
  }
}

class BoardListFilterChips extends StatelessWidget {
  const BoardListFilterChips({
    super.key,
    this.showcaseKey,
    required this.description,
    required this.mineLabel,
    required this.memberLabel,
    required this.allLabel,
    required this.isMineSelected,
    required this.isMemberSelected,
    required this.isAllSelected,
    required this.onMineSelected,
    required this.onMemberSelected,
    required this.onAllSelected,
  });

  final GlobalKey? showcaseKey;
  final String description;
  final String mineLabel;
  final String memberLabel;
  final String allLabel;
  final bool isMineSelected;
  final bool isMemberSelected;
  final bool isAllSelected;
  final VoidCallback onMineSelected;
  final VoidCallback onMemberSelected;
  final VoidCallback onAllSelected;

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color borderColor,
    required VoidCallback onSelected,
  }) {
    final p = context.appTheme;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        side: BorderSide(
          color: borderColor,
          width: ConfigUI.borderWidthBrutal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: ConfigUI.chipRadius,
        ),
        color: WidgetStateProperty.resolveWith<Color?>((_) => p.cardBackground),
        backgroundColor: p.cardBackground,
        selectedColor: p.cardBackground,
        labelStyle: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        pressElevation: 0,
        elevation: 0,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showCheckmark: true,
        checkmarkColor: borderColor,
      ),
    );
  }

  Widget _wrapShowcase({
    required BuildContext context,
    GlobalKey? key,
    required String description,
    required Widget child,
  }) {
    if (key == null) return child;
    final p = context.appTheme;
    return Showcase(
      key: key,
      description: description,
      tooltipBackgroundColor: p.sheetBackground,
      textColor: p.textOnSheet,
      tooltipBorderRadius: ConfigUI.cardRadius,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return _wrapShowcase(
      context: context,
      key: showcaseKey,
      description: description,
      child: Wrap(
        spacing: ConfigUI.boardListFilterChipGap,
        children: [
          _buildFilterChip(
            context: context,
            label: mineLabel,
            selected: isMineSelected,
            borderColor: p.boardMineBorder,
            onSelected: onMineSelected,
          ),
          _buildFilterChip(
            context: context,
            label: memberLabel,
            selected: isMemberSelected,
            borderColor: p.boardMemberBorder,
            onSelected: onMemberSelected,
          ),
          _buildFilterChip(
            context: context,
            label: allLabel,
            selected: isAllSelected,
            borderColor: p.borderBrutal,
            onSelected: onAllSelected,
          ),
        ],
      ),
    );
  }
}
