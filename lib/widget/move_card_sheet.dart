// move_card_sheet.dart
// 컬럼 간 카드 이동 바텀시트 (UI/UX 설계서 5.2)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/sheet_util.dart';
import 'package:syncflow/vm/board_detail_notifier.dart';
import 'package:syncflow/vm/card_handler.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/vm/ws_service_notifier.dart';
import 'package:syncflow/service/api_client.dart';

/// 컬럼 간 카드 이동 바텀시트
void showMoveCardSheet(
  BuildContext context, {
  required int boardId,
  required CardItem card,
  required int fromColumnId,
  required List<ColumnItem> columns,
  required VoidCallback onRefresh,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: defaultSheetShape,
    builder: (ctx) => _MoveCardSheetContent(
      boardId: boardId,
      card: card,
      fromColumnId: fromColumnId,
      columns: columns,
      onRefresh: onRefresh,
    ),
  );
}

class _MoveCardSheetContent extends ConsumerStatefulWidget {
  const _MoveCardSheetContent({
    required this.boardId,
    required this.card,
    required this.fromColumnId,
    required this.columns,
    required this.onRefresh,
  });

  final int boardId;
  final CardItem card;
  final int fromColumnId;
  final List<ColumnItem> columns;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_MoveCardSheetContent> createState() => _MoveCardSheetContentState();
}

class _MoveCardSheetContentState extends ConsumerState<_MoveCardSheetContent> {
  int? _selectedColumnId;
  bool _loading = false;

  List<ColumnItem> get _targetColumns =>
      widget.columns.where((c) => c.id != widget.fromColumnId).toList();

  @override
  void initState() {
    super.initState();
    if (_targetColumns.isNotEmpty) {
      _selectedColumnId = _targetColumns.first.id;
    }
  }

  Future<void> _executeMove() async {
    if (_selectedColumnId == null) return;
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final ws = ref.read(wsServiceProvider);
      if (ws.isConnected) {
        final targetColumnId = _selectedColumnId!;
        final detail = ref.read(boardDetailCacheProvider(widget.boardId)) ??
            ref.read(boardDetailProvider(widget.boardId)).value;
        final targetCards = (detail?.cards ?? const <CardItem>[])
            .where((c) => c.columnId == targetColumnId)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        final topCardId = targetCards.isNotEmpty ? targetCards.first.id : null;
        final optimisticPosition = targetCards.isNotEmpty ? targetCards.first.position - 1 : 0;
        final reqId = 'move_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
        await ws.moveCard(
          boardId: widget.boardId,
          cardId: widget.card.id,
          toColumnId: targetColumnId,
          afterCardId: topCardId,
          reqId: reqId,
        );
        ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = {
          ...ref.read(optimisticCardMovesProvider(widget.boardId)),
          widget.card.id: OptimisticCardMove(
            columnId: targetColumnId,
            position: optimisticPosition,
          ),
        };
      } else {
        final token = ref.read(sessionNotifierProvider).value?.sessionToken;
        if (token == null) return;
        await ref.read(cardHandlerProvider).updateCard(
          token,
          widget.card.id,
          columnId: _selectedColumnId!,
          position: 0,
        );
        widget.onRefresh();
      }
      if (mounted) {
        CustomNavigationUtil.back(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final targets = _targetColumns;

    return Padding(
      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.2),
                  borderRadius: ConfigUI.chipRadius,
                ),
                child: Text(
                  context.tr('moveMode'),
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeCaption,
                    fontWeight: FontWeight.bold,
                    color: p.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.card.title,
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeSubtitle,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('moveCardToColumn'),
            style: TextStyle(
              fontSize: ConfigUI.fontSizeLabel,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...targets.map((col) => RadioListTile<int>(
                value: col.id,
                groupValue: _selectedColumnId,
                onChanged: _loading ? null : (v) => setState(() => _selectedColumnId = v),
                title: Text(
                  col.title,
                  style: TextStyle(color: p.textPrimary),
                ),
                dense: true,
              )),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: _loading ? null : () => CustomNavigationUtil.back(context),
                child: Text(context.tr('cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_loading || _selectedColumnId == null) ? null : _executeMove,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('moveComplete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
