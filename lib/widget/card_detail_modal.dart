// card_detail_modal.dart
// 카드 상세 모달 (제목/설명 수정)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/vm/card_handler.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/vm/ws_service_notifier.dart';

/// 카드 상세 모달
class CardDetailModal extends ConsumerStatefulWidget {
  const CardDetailModal({
    super.key,
    required this.card,
    required this.boardId,
    required this.onRefresh,
  });

  final CardItem card;
  final int boardId;
  final VoidCallback onRefresh;

  @override
  ConsumerState<CardDetailModal> createState() => _CardDetailModalState();
}

class _CardDetailModalState extends ConsumerState<CardDetailModal> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descController = TextEditingController(text: widget.card.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _loading = true);
    try {
      final session = ref.read(sessionNotifierProvider).value;
      final token = session?.sessionToken;
      if (token == null) return;

      final ws = ref.read(wsServiceProvider);
      if (ws.isConnected) {
        final reqId = 'update_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
        await ws.updateCard(
          boardId: widget.boardId,
          cardId: widget.card.id,
          patch: {
            'title': title,
            'description': _descController.text.trim().isEmpty ? '' : _descController.text.trim(),
          },
          reqId: reqId,
        );
        if (mounted) CustomNavigationUtil.back(context);
        return;
      }

      await ref.read(cardHandlerProvider).updateCard(
        token,
        widget.card.id,
        title: title,
        description: _descController.text.trim().isEmpty ? '' : _descController.text.trim(),
      );
      widget.onRefresh();
      if (mounted) CustomNavigationUtil.back(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _archive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카드 삭제'),
        content: const Text('이 카드를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final session = ref.read(sessionNotifierProvider).value;
      final token = session?.sessionToken;
      if (token == null) return;

      final ws = ref.read(wsServiceProvider);
      if (ws.isConnected) {
        final reqId = 'archive_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
        await ws.archiveCard(
          boardId: widget.boardId,
          cardId: widget.card.id,
          reqId: reqId,
        );
        if (mounted) CustomNavigationUtil.back(context);
        return;
      }

      await ref.read(cardHandlerProvider).archiveCard(token, widget.card.id);
      widget.onRefresh();
      if (mounted) CustomNavigationUtil.back(context);
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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: p.sheetBackground,
            child: Column(
              children: [
                // 핸들
                Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
                  children: [
                    Text(
                      '카드 상세',
                      style: TextStyle(
                        fontSize: ConfigUI.fontSizeSubtitle,
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '제목',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: '설명',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('저장'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _loading ? null : _archive,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.accent,
                          ),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}
