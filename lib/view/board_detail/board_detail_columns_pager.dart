part of 'package:syncflow/view/board_detail_screen.dart';
// 컬럼 탭 + PageView 페이징 컨테이너
//
// [구조 하이라키]
// _BoardColumnsView
// └─ _BoardColumnsViewState
//    ├─ BoardDetailColumnTabsBar
//    └─ PageView.builder -> _ColumnView

/// 컬럼 탭과 페이지 전환 영역을 묶는 컨테이너.
class _BoardColumnsView extends ConsumerStatefulWidget {
  const _BoardColumnsView({
    required this.detail,
    required this.boardId,
    required this.isOwner,
    required this.onRefresh,
    this.optimisticMoves = const <int, OptimisticCardMove>{},
  });

  final BoardDetail detail;
  final int boardId;
  final bool isOwner;
  final VoidCallback onRefresh;
  final Map<int, OptimisticCardMove> optimisticMoves;

  @override
  ConsumerState<_BoardColumnsView> createState() => _BoardColumnsViewState();
}

/// 상태 필터: 전체 / 완료 / 미완료
enum _StatusFilter { all, done, notDone }

class _BoardColumnsViewState extends ConsumerState<_BoardColumnsView> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _mentionOnly = false;
  _StatusFilter _statusFilter = _StatusFilter.all;

  /// 페이지 컨트롤러를 초기화한다.
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  /// 컨트롤러 리소스를 해제한다.
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<CardItem> _applyStatusFilter(List<CardItem> cards) {
    switch (_statusFilter) {
      case _StatusFilter.done:
        return cards.where((c) => c.status == 'done').toList();
      case _StatusFilter.notDone:
        return cards.where((c) => c.status != 'done').toList();
      case _StatusFilter.all:
        return cards;
    }
  }

  Widget _buildFilterRow(BuildContext context, int? myUserId) {
    final p = context.appTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          selected: _mentionOnly,
          onSelected: myUserId == null
              ? null
              : (v) => setState(() => _mentionOnly = v),
          label: Text(context.tr('mentionOnlyFilter')),
          side: BorderSide(color: p.borderBrutal, width: ConfigUI.borderWidthBrutal),
          shape: RoundedRectangleBorder(borderRadius: ConfigUI.chipRadius),
        ),
        const SizedBox(width: 8),
        FilterChip(
          selected: _statusFilter == _StatusFilter.all,
          onSelected: (_) => setState(() => _statusFilter = _StatusFilter.all),
          label: Text(context.tr('all')),
          side: BorderSide(color: p.borderBrutal, width: ConfigUI.borderWidthBrutal),
          shape: RoundedRectangleBorder(borderRadius: ConfigUI.chipRadius),
        ),
        const SizedBox(width: 8),
        FilterChip(
          selected: _statusFilter == _StatusFilter.done,
          onSelected: (_) => setState(() => _statusFilter = _StatusFilter.done),
          label: Text(context.tr('filterStatusDone')),
          side: BorderSide(color: p.borderBrutal, width: ConfigUI.borderWidthBrutal),
          shape: RoundedRectangleBorder(borderRadius: ConfigUI.chipRadius),
        ),
        const SizedBox(width: 8),
        FilterChip(
          selected: _statusFilter == _StatusFilter.notDone,
          onSelected: (_) => setState(() => _statusFilter = _StatusFilter.notDone),
          label: Text(context.tr('filterStatusNotDone')),
          side: BorderSide(color: p.borderBrutal, width: ConfigUI.borderWidthBrutal),
          shape: RoundedRectangleBorder(borderRadius: ConfigUI.chipRadius),
        ),
      ],
    );
  }

  /// 컬럼 탭 바와 페이지 본문을 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final columns = widget.detail.columns;
    final myUserId = ref.watch(sessionNotifierProvider).value?.userId;

    return Column(
      children: [
        BoardDetailColumnTabsBar(
          columns: columns,
          currentIndex: _currentIndex,
          onTapColumn: (index) => _pageController.animateToPage(
            index,
            duration: ConfigUI.durationMedium,
            curve: Curves.easeInOut,
          ),
          filterRow: _buildFilterRow(context, myUserId),
          isOwner: widget.isOwner,
          manageButton: _ColumnManageButton(
            boardId: widget.boardId,
            columns: columns,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: columns.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final col = columns[index];
              final merged = mergeCardsWithOptimistic(
                widget.detail.cards,
                widget.optimisticMoves,
              );
              final allInColumn = merged
                  .where((c) => c.columnId == col.id)
                  .toList();
              var cards = (_mentionOnly && myUserId != null)
                  ? allInColumn
                        .where((c) => c.mentionedUserIds.contains(myUserId))
                        .toList()
                  : allInColumn;
              cards = _applyStatusFilter(cards);
              cards.sort((a, b) => a.position.compareTo(b.position));
              final cardsKey = cards
                  .map((c) => '${c.id}:${c.position}')
                  .join(',');
              return _ColumnView(
                key: ValueKey('col_${col.id}_$cardsKey'),
                column: col,
                cards: cards,
                columns: columns,
                boardId: widget.boardId,
                onRefresh: widget.onRefresh,
                mentionOnlyMode: _mentionOnly,
              );
            },
          ),
        ),
      ],
    );
  }
}
