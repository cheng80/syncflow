part of 'package:syncflow/view/board_detail_screen.dart';
// 단일 컬럼 뷰 + 카드 재정렬 + 카드 추가 시트

/// 담당자 필터 드롭다운 (전체/미지정/멤버)
class _AssigneeFilterDropdown extends StatelessWidget {
  const _AssigneeFilterDropdown({
    required this.members,
    required this.value,
    required this.onChanged,
  });

  final List<BoardMemberItem> members;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isDense: true,
          iconSize: 18,
          isExpanded: true,
          menuMaxHeight: 300,
          menuWidth: 280,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                context.tr('all'),
                style: TextStyle(fontSize: ConfigUI.fontSizeLabel),
              ),
            ),
            DropdownMenuItem<int?>(
              value: _assigneeFilterUnassigned,
              child: Text(
                context.tr('assigneeNone'),
                style: TextStyle(fontSize: ConfigUI.fontSizeLabel),
              ),
            ),
            ...members.map(
              (m) => DropdownMenuItem<int?>(
                value: m.userId,
                child: Text(
                  m.email,
                  style: TextStyle(fontSize: ConfigUI.fontSizeLabel),
                ),
              ),
            ),
          ],
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }
}
//
// [구조 하이라키]
// _ColumnView
// └─ _ColumnViewState
//    ├─ 목록 동기화/비교(_listEquals)
//    ├─ 재정렬 처리(_onReorder)
//    ├─ 위치 계산(_compute*)
//    └─ ACK 재시도(_scheduleMoveAckRetry)
// _AddCardSheet
// └─ _AddCardSheetState(_save)

/// 단일 컬럼의 헤더/카드 목록/추가 버튼을 렌더링하는 뷰.
class _ColumnView extends ConsumerStatefulWidget {
  const _ColumnView({
    super.key,
    required this.column,
    required this.cards,
    required this.columns,
    required this.boardId,
    required this.onRefresh,
    this.mentionOnlyMode = false,
    this.members = const [],
    this.assigneeFilterId,
    this.onAssigneeFilterChanged,
  });

  final ColumnItem column;
  final List<CardItem> cards;
  final List<ColumnItem> columns;
  final int boardId;
  final VoidCallback onRefresh;
  final bool mentionOnlyMode;
  final List<BoardMemberItem> members;
  final int? assigneeFilterId;
  final ValueChanged<int?>? onAssigneeFilterChanged;

  @override
  ConsumerState<_ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends ConsumerState<_ColumnView> {
  late List<CardItem> _displayCards;
  static const Duration _moveAckTimeout = Duration(seconds: 2);

  /// 첫 진입 시 전달받은 카드 목록을 표시 상태로 초기화한다.
  @override
  void initState() {
    super.initState();
    _displayCards = List.from(widget.cards);
  }

  /// 상위에서 카드 목록이 바뀌면 표시 목록을 동기화한다.
  @override
  void didUpdateWidget(_ColumnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = !_listEquals(widget.cards, oldWidget.cards);
    if (changed) {
      _displayCards = List.from(widget.cards);
    }
  }

  /// 카드 목록의 의미 있는 변경 여부를 비교한다.
  bool _listEquals(List<CardItem> a, List<CardItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position != b[i].position ||
          a[i].columnId != b[i].columnId ||
          a[i].title != b[i].title ||
          a[i].description != b[i].description ||
          a[i].priority != b[i].priority ||
          a[i].assigneeId != b[i].assigneeId ||
          a[i].status != b[i].status ||
          !_intListEquals(a[i].mentionedUserIds, b[i].mentionedUserIds)) {
        return false;
      }
    }
    return true;
  }

  bool _intListEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 카드 추가 시트를 연다.
  void _showAddCardDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(ctx).size.height *
              ConfigUI.addCardSheetMaxHeightFactor,
        ),
        child: _AddCardSheet(
          columnId: widget.column.id,
          boardId: widget.boardId,
          onSaved: () => CustomNavigationUtil.back(ctx),
        ),
      ),
    );
  }

  /// 컬럼 헤더와 카드 리스트(재정렬 가능)를 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final myUserId = ref.watch(sessionNotifierProvider).value?.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onAssigneeFilterChanged != null) ...[
                Text(
                  context.tr('assignee'),
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeLabel,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _AssigneeFilterDropdown(
                  members: widget.members,
                  value: widget.assigneeFilterId,
                  onChanged: widget.onAssigneeFilterChanged!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.15),
                    borderRadius: ConfigUI.cardRadius,
                    border: Border.all(
                      color: p.borderBrutal,
                      width: ConfigUI.borderWidthBrutal,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        widget.column.title,
                        style: TextStyle(
                          fontSize: ConfigUI.fontSizeSubtitle,
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (!widget.mentionOnlyMode)
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          iconSize: 20,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                          ),
                          onPressed: _showAddCardDialog,
                          tooltip: context.tr('cardAdd'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ConfigUI.gapColumnHeaderToCards),
        Expanded(
          child: widget.mentionOnlyMode
              ? _buildMentionOnlyList(myUserId)
              : ReorderableListView.builder(
                  padding: EdgeInsets.only(
                    left: ConfigUI.screenPaddingH,
                    right: ConfigUI.screenPaddingH,
                    top: 0,
                    bottom: ConfigUI.gapBetweenCards,
                  ),
                  itemCount: _displayCards.length + 1,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(oldIndex, newIndex),
                  proxyDecorator: (child, index, animation) {
                    final scale = Tween<double>(
                      begin: 1,
                      end: 1.04,
                    ).animate(animation);
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, childWidget) => Transform.scale(
                        scale: scale.value,
                        child: Material(
                          elevation: ConfigUI.elevationDragProxy,
                          borderRadius: ConfigUI.cardRadius,
                          child: child,
                        ),
                      ),
                    );
                  },
                  buildDefaultDragHandles: true,
                  itemBuilder: (context, index) {
                    if (index == _displayCards.length) {
                      return Padding(
                        key: const ValueKey('add-button'),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: OutlinedButton.icon(
                          onPressed: _showAddCardDialog,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(context.tr('cardAdd')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      );
                    }
                    final card = _displayCards[index];
                    return Padding(
                      key: ValueKey(card.id),
                      padding: const EdgeInsets.only(
                        bottom: ConfigUI.gapBetweenCards,
                      ),
                      child: CardTile(
                        card: card,
                        onTap: () => _showCardDetail(card),
                        onRefresh: widget.onRefresh,
                        onToggleDone: (nextDone) =>
                            _toggleCardDone(card, nextDone),
                        showMentionBadge:
                            myUserId != null &&
                            card.mentionedUserIds.contains(myUserId),
                        onMove: widget.columns.length > 1
                            ? () => showMoveCardSheet(
                                context,
                                boardId: widget.boardId,
                                card: card,
                                fromColumnId: widget.column.id,
                                columns: widget.columns,
                                onRefresh: widget.onRefresh,
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMentionOnlyList(int? myUserId) {
    if (_displayCards.isEmpty) {
      return Center(child: Text(context.tr('mentionOnlyEmpty')));
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: ConfigUI.screenPaddingH,
        right: ConfigUI.screenPaddingH,
        top: 0,
        bottom: ConfigUI.gapBetweenCards,
      ),
      itemCount: _displayCards.length,
      itemBuilder: (context, index) {
        final card = _displayCards[index];
        return Padding(
          key: ValueKey(card.id),
          padding: const EdgeInsets.only(bottom: ConfigUI.gapBetweenCards),
          child: CardTile(
            card: card,
            onTap: () => _showCardDetail(card),
            onRefresh: widget.onRefresh,
            onToggleDone: (nextDone) => _toggleCardDone(card, nextDone),
            showMentionBadge:
                myUserId != null && card.mentionedUserIds.contains(myUserId),
            onMove: null,
          ),
        );
      },
    );
  }

  /// 카드 완료 상태(active/done)를 토글한다.
  Future<void> _toggleCardDone(CardItem card, bool nextDone) async {
    final nextStatus = nextDone ? 'done' : 'active';
    if (card.status == nextStatus) return;

    final ws = ref.read(wsServiceProvider);
    if (ws.isConnected) {
      final reqId =
          'status_${widget.boardId}_${card.id}_${DateTime.now().microsecondsSinceEpoch}';
      await ws.updateCard(
        boardId: widget.boardId,
        cardId: card.id,
        patch: {'status': nextStatus},
        reqId: reqId,
      );
      return;
    }

    final token = ref.read(sessionNotifierProvider).value?.sessionToken;
    if (token == null) return;
    try {
      await ref
          .read(cardHandlerProvider)
          .updateCard(token, card.id, status: nextStatus);
      widget.onRefresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// 드래그 재정렬을 처리한다.
  /// WS 우선 전송, 미연결 시 REST 폴백, 실패 시 롤백을 수행한다.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final session = ref.read(sessionNotifierProvider).value;

    if (oldIndex >= _displayCards.length) {
      return;
    }
    if (newIndex > _displayCards.length) {
      newIndex = _displayCards.length;
    }
    if (oldIndex == newIndex) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;

    final movedCard = _displayCards.removeAt(oldIndex);
    _displayCards.insert(newIndex, movedCard);
    final neighbor = _computeNeighborIds(_displayCards, newIndex);

    // 서버 전송용 position은 중복되지 않게 계산해야 한다.
    // (동일 position 전송 시 서버 정렬(position,id)에서 원위치될 수 있음)
    final requestPosition = _computeRequestPosition(_displayCards, newIndex);

    // 서버 재정렬 규칙과 동일하게 로컬도 즉시 정규화
    final normalized = List.generate(
      _displayCards.length,
      (i) => _displayCards[i].copyWith(position: i * 1000),
    );
    _displayCards = normalized;
    setState(() {}); // 즉시 UI 반영
    final newPosition = requestPosition;
    final affectedCardIds = normalized.map((c) => c.id).toSet();

    // 1. 낙관적 업데이트: 변경된 컬럼의 카드 전체를 일관된 순서로 반영
    final optimistic = Map<int, OptimisticCardMove>.from(
      ref.read(optimisticCardMovesProvider(widget.boardId)),
    );
    for (final card in normalized) {
      optimistic[card.id] = OptimisticCardMove(
        columnId: widget.column.id,
        position: card.position,
      );
    }
    ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
        optimistic;

    final ws = ref.read(wsServiceProvider);
    if (ws.isConnected) {
      final reqId = _newMoveReqId(movedCard.id);
      ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state = {
        ...ref.read(pendingMoveReqIdsProvider(widget.boardId)),
        reqId,
      };
      ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = {
        ...ref.read(pendingMoveRetryCountProvider(widget.boardId)),
        reqId: 0,
      };

      Future<void> sendMove() async {
        await ws.moveCard(
          boardId: widget.boardId,
          cardId: movedCard.id,
          toColumnId: widget.column.id,
          beforeCardId: neighbor.$1,
          afterCardId: neighbor.$2,
          reqId: reqId,
        );
      }

      try {
        await sendMove();
        _scheduleMoveAckRetry(
          reqId: reqId,
          sendMove: sendMove,
          affectedCardIds: affectedCardIds,
        );
        // CARD_MOVED(req_id 동일) ACK 수신 시 _BoardWsBridge에서 invalidate → 서버 데이터로 확정
      } catch (e, st) {
        debugPrint('[카드이동] WebSocket 실패: $e\n$st');
        if (mounted) {
          final pending = Set<String>.from(
            ref.read(pendingMoveReqIdsProvider(widget.boardId)),
          )..remove(reqId);
          ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state =
              pending;
          final retryMap = Map<String, int>.from(
            ref.read(pendingMoveRetryCountProvider(widget.boardId)),
          )..remove(reqId);
          ref
                  .read(pendingMoveRetryCountProvider(widget.boardId).notifier)
                  .state =
              retryMap;
          final rollback = Map<int, OptimisticCardMove>.from(
            ref.read(optimisticCardMovesProvider(widget.boardId)),
          );
          rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
          ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
              rollback;
          widget.onRefresh();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.tr('cardMoveFailed'))));
        }
      }
      return;
    }

    // WebSocket 미연결 시 REST API 폴백
    final token = session?.sessionToken;
    if (token == null) {
      final rollback = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
          rollback;
      widget.onRefresh();
      return;
    }
    try {
      await ref
          .read(cardHandlerProvider)
          .updateCard(
            token,
            movedCard.id,
            columnId: widget.column.id,
            position: newPosition,
          );
      final committed = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      committed.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
          committed;
      widget.onRefresh();
    } on ApiException catch (e) {
      if (mounted) {
        final rollback = Map<int, OptimisticCardMove>.from(
          ref.read(optimisticCardMovesProvider(widget.boardId)),
        );
        rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
        ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
            rollback;
        widget.onRefresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// 카드 상세 시트를 연다.
  void _showCardDetail(CardItem card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CardDetailModal(
        card: card,
        boardId: widget.boardId,
        onRefresh: widget.onRefresh,
      ),
    );
  }

  /// 서버 전송용 position 값을 계산한다.
  int _computeRequestPosition(List<CardItem> reorderedCards, int newIndex) {
    if (reorderedCards.length <= 1) return 0;

    if (newIndex == 0) {
      return reorderedCards[1].position - 1000;
    }

    if (newIndex == reorderedCards.length - 1) {
      return reorderedCards[newIndex - 1].position + 1000;
    }

    final prev = reorderedCards[newIndex - 1].position;
    final next = reorderedCards[newIndex + 1].position;
    var mid = (prev + next) ~/ 2;

    // 간격이 좁아 중복될 수 있으면 최소 1만큼 차이를 둔다.
    if (mid <= prev) mid = prev + 1;
    if (mid >= next) mid = next - 1;
    return mid;
  }

  /// 이동 대상 기준 이웃 카드(before/after) ID를 계산한다.
  (int?, int?) _computeNeighborIds(
    List<CardItem> reorderedCards,
    int newIndex,
  ) {
    final beforeId = newIndex > 0 ? reorderedCards[newIndex - 1].id : null;
    final afterId = newIndex < reorderedCards.length - 1
        ? reorderedCards[newIndex + 1].id
        : null;
    return (beforeId, afterId);
  }

  /// 이동 요청 추적용 req_id를 생성한다.
  String _newMoveReqId(int cardId) =>
      'move_${widget.boardId}_${cardId}_${DateTime.now().microsecondsSinceEpoch}';

  /// ACK 타임아웃 시 1회 재전송 후 실패하면 롤백/재조회한다.
  void _scheduleMoveAckRetry({
    required String reqId,
    required Future<void> Function() sendMove,
    required Set<int> affectedCardIds,
  }) {
    Future.delayed(_moveAckTimeout, () async {
      if (!mounted) return;

      final pending = ref.read(pendingMoveReqIdsProvider(widget.boardId));
      if (!pending.contains(reqId)) return; // ACK 완료

      final retryMap = Map<String, int>.from(
        ref.read(pendingMoveRetryCountProvider(widget.boardId)),
      );
      final retryCount = retryMap[reqId] ?? 0;

      if (retryCount < 1) {
        retryMap[reqId] = retryCount + 1;
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state =
            retryMap;
        try {
          await sendMove();
          _scheduleMoveAckRetry(
            reqId: reqId,
            sendMove: sendMove,
            affectedCardIds: affectedCardIds,
          );
          return;
        } catch (e) {
          debugPrint('[카드이동] 재전송 실패(req_id=$reqId): $e');
        }
      }

      // 재시도 후에도 ACK 없으면 롤백 + 스냅샷 재조회
      final nextPending = Set<String>.from(
        ref.read(pendingMoveReqIdsProvider(widget.boardId)),
      )..remove(reqId);
      ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state =
          nextPending;

      retryMap.remove(reqId);
      ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state =
          retryMap;

      final rollback = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
          rollback;

      ref.invalidate(boardDetailProvider(widget.boardId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('syncRefresh'))));
      }
    });
  }
}

/// 카드 생성 입력 시트.
class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet({
    required this.columnId,
    required this.boardId,
    required this.onSaved,
  });

  final int columnId;
  final int boardId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  /// 입력 컨트롤러 리소스를 해제한다.
  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 카드 생성 요청을 수행한다. (WS 우선, 미연결 시 REST 폴백)
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
        final reqId =
            'create_${widget.boardId}_${widget.columnId}_${DateTime.now().microsecondsSinceEpoch}';
        await ws.createCard(
          boardId: widget.boardId,
          columnId: widget.columnId,
          title: title,
          description: _descController.text.trim().isEmpty
              ? ''
              : _descController.text.trim(),
          reqId: reqId,
        );
        widget.onSaved();
        return;
      }

      await ref
          .read(cardHandlerProvider)
          .createCard(
            token,
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            columnId: widget.columnId,
          );
      ref.invalidate(boardDetailProvider(widget.boardId));
      widget.onSaved();
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

  /// 카드 생성 입력 폼 UI를 렌더링한다.
  @override
  Widget build(BuildContext context) {
    return KeyboardDismissScrollView(
      child: Padding(
        padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.tr('newCard'),
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeSubtitle,
                    fontWeight: FontWeight.bold,
                    color: context.appTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.tr('markdownHelp'),
                  onPressed: () => showMarkdownHelpDialog(context),
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: ConfigUI.cardTitleMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                hintText: context.tr('cardTitle'),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLength: ConfigUI.cardDescriptionMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [
                MaxLinesTextInputFormatter(ConfigUI.cardDescriptionMaxLines),
              ],
              decoration: InputDecoration(
                hintText: context.tr('descriptionOptional'),
                border: const OutlineInputBorder(),
              ),
              minLines: ConfigUI.addCardDescriptionMinLines,
              maxLines: ConfigUI.addCardDescriptionMaxVisibleLines,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('add')),
            ),
          ],
        ),
      ),
    );
  }
}
