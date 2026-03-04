// card_detail_modal.dart
// 카드 상세 모달 (제목/설명 수정)

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/vm/card_handler.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/markdown_input_formatter.dart';
import 'package:syncflow/vm/board_detail_notifier.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/vm/ws_service_notifier.dart';
import 'package:syncflow/widget/card_markdown_preview.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';
import 'package:syncflow/widget/markdown_help_dialog.dart';

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
  late final dynamic _wsService;
  bool _loading = false;
  late String _status;
  Timer? _lockRenewTimer;
  bool _lockOwner = false;
  String? _lockMessage;
  static const _lockRenewInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _wsService = ref.read(wsServiceProvider);
    _titleController = TextEditingController(text: widget.card.title);
    _descController = TextEditingController(text: widget.card.description);
    _status = widget.card.status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAcquireLock();
    });
  }

  @override
  void dispose() {
    _releaseLock();
    _lockRenewTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _tryAcquireLock() async {
    final session = ref.read(sessionNotifierProvider).value;
    final userId = session?.userId;
    if (!_wsService.isConnected || userId == null) return;

    final lockReqId =
        'lock_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
    await _wsService.acquireLock(
      boardId: widget.boardId,
      cardId: widget.card.id,
      reqId: lockReqId,
    );

    // 잠금 상태 평가
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _syncLockUi();
    });
  }

  void _syncLockUi() {
    final lock = ref.read(cardLocksProvider(widget.boardId))[widget.card.id];
    final me = ref.read(sessionNotifierProvider).value?.userId;
    if (lock == null) {
      setState(() {
        _lockOwner = false;
        _lockMessage = null;
      });
      _lockRenewTimer?.cancel();
      return;
    }
    final mine = me != null && lock.lockedByUserId == me;
    setState(() {
      _lockOwner = mine;
      _lockMessage = mine
          ? null
          : context.tr(
              'cardLockedBy',
              namedArgs: {'name': lock.lockedByDisplay},
            );
    });
    if (mine) {
      _startLockRenew();
    } else {
      _lockRenewTimer?.cancel();
    }
  }

  void _startLockRenew() {
    _lockRenewTimer?.cancel();
    _lockRenewTimer = Timer.periodic(_lockRenewInterval, (_) async {
      if (!_wsService.isConnected || !_lockOwner) return;
      await _wsService.renewLock(
        boardId: widget.boardId,
        cardId: widget.card.id,
      );
    });
  }

  Future<void> _releaseLock() async {
    if (!_wsService.isConnected) return;
    if (!_lockOwner) return;
    await _wsService.releaseLock(
      boardId: widget.boardId,
      cardId: widget.card.id,
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (_lockMessage != null) return;

    setState(() => _loading = true);
    try {
      final session = ref.read(sessionNotifierProvider).value;
      final token = session?.sessionToken;
      if (token == null) return;

      if (_wsService.isConnected) {
        final reqId =
            'update_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
        await _wsService.updateCard(
          boardId: widget.boardId,
          cardId: widget.card.id,
          patch: {
            'title': title,
            'description': _descController.text.trim().isEmpty
                ? ''
                : _descController.text.trim(),
            'status': _status,
          },
          reqId: reqId,
        );
        if (mounted) CustomNavigationUtil.back(context);
        return;
      }

      await ref
          .read(cardHandlerProvider)
          .updateCard(
            token,
            widget.card.id,
            title: title,
            description: _descController.text.trim().isEmpty
                ? ''
                : _descController.text.trim(),
            status: _status,
          );
      widget.onRefresh();
      if (mounted) CustomNavigationUtil.back(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _detectedMentions() {
    final source = '${_titleController.text} ${_descController.text}';
    final regex = RegExp(r'@([^\s@,;:(){}\[\]<>]+)');
    final seen = <String>{};
    final result = <String>[];
    for (final m in regex.allMatches(source)) {
      final raw = m.group(1);
      if (raw == null || raw.isEmpty) continue;
      final token = '@$raw';
      if (seen.add(token)) {
        result.add(token);
      }
    }
    return result;
  }

  InlineSpan _buildMentionHighlightedText(String text, BuildContext context) {
    final p = context.appTheme;
    final regex = RegExp(r'@([^\s@,;:(){}\[\]<>]+)');
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: TextStyle(color: p.textSecondary),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: p.primary,
            fontWeight: FontWeight.w700,
            backgroundColor: p.primary.withValues(alpha: 0.14),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: TextStyle(color: p.textSecondary),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: p.textSecondary),
        ),
      );
    }
    return TextSpan(children: spans);
  }

  void _toggleDone(bool nextDone) {
    if (_loading || _lockMessage != null) return;
    setState(() => _status = nextDone ? 'done' : 'active');
  }

  Future<void> _archive() async {
    if (_lockMessage != null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('cardDelete')),
        content: Text(context.tr('cardDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('delete')),
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

      if (_wsService.isConnected) {
        final reqId =
            'archive_${widget.boardId}_${widget.card.id}_${DateTime.now().microsecondsSinceEpoch}';
        await _wsService.archiveCard(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final myUserId = ref.watch(sessionNotifierProvider).value?.userId;
    final mentionedToMe =
        myUserId != null && widget.card.mentionedUserIds.contains(myUserId);
    ref.listen<Map<int, CardLockState>>(cardLocksProvider(widget.boardId), (
      prev,
      next,
    ) {
      if (!mounted) return;
      if (next.containsKey(widget.card.id) ||
          (prev?.containsKey(widget.card.id) ?? false)) {
        _syncLockUi();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GestureDetector(
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
                    child: KeyboardDismissScrollView(
                      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
                      keyboardPadding: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.tr('cardDetail'),
                                style: TextStyle(
                                  fontSize: ConfigUI.fontSizeSubtitle,
                                  fontWeight: FontWeight.bold,
                                  color: p.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: (_loading || _lockMessage != null)
                                    ? null
                                    : _save,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(context.tr('save')),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: (_loading || _lockMessage != null)
                                    ? null
                                    : _archive,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  foregroundColor: p.accent,
                                ),
                                child: Text(context.tr('delete')),
                              ),
                            ],
                          ),
                          if (_lockMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: p.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p.accent.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                _lockMessage!,
                                style: TextStyle(
                                  color: p.accent,
                                  fontSize: ConfigUI.fontSizeLabel,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _status == 'done',
                                onChanged: (_lockMessage != null || _loading)
                                    ? null
                                    : (v) => _toggleDone(v ?? false),
                              ),
                              Text(
                                context.tr('cardStatusDone'),
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: ConfigUI.fontSizeBody,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: context.tr('markdownHelp'),
                                onPressed: () =>
                                    showMarkdownHelpDialog(context),
                                icon: const Icon(Icons.help_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            enabled: _lockMessage == null && !_loading,
                            maxLength: ConfigUI.cardTitleMaxLength,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            decoration: InputDecoration(
                              labelText: context.tr('cardTitle'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descController,
                            enabled: _lockMessage == null && !_loading,
                            maxLength: ConfigUI.cardDescriptionMaxLength,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            inputFormatters: [
                              MaxLinesTextInputFormatter(
                                ConfigUI.cardDescriptionMaxLines,
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: context.tr('cardDescription'),
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('mentionInputHint'),
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: ConfigUI.fontSizeLabel,
                            ),
                          ),
                          if (mentionedToMe) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: p.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p.primary.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                context.tr('mentionedToMe'),
                                style: TextStyle(
                                  color: p.primary,
                                  fontSize: ConfigUI.fontSizeLabel,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (_detectedMentions().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _detectedMentions()
                                  .map(
                                    (token) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        token,
                                        style: TextStyle(
                                          color: p.primary,
                                          fontSize: ConfigUI.fontSizeLabel,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (mentionedToMe &&
                              _descController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            RichText(
                              text: _buildMentionHighlightedText(
                                _descController.text.trim(),
                                context,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            context.tr('preview'),
                            style: TextStyle(
                              fontSize: ConfigUI.fontSizeLabel,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.cardBackground,
                              borderRadius: ConfigUI.inputRadius,
                              border: Border.all(color: p.divider),
                            ),
                            child: CardMarkdownPreview(
                              text: _descController.text.trim(),
                              emptyText: context.tr('previewEmpty'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Spacer(),
                              FilledButton(
                                onPressed: (_loading || _lockMessage != null)
                                    ? null
                                    : _save,
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(context.tr('save')),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: (_loading || _lockMessage != null)
                                    ? null
                                    : _archive,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.accent,
                                ),
                                child: Text(context.tr('delete')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
