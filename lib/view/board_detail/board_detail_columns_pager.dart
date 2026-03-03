part of 'package:syncflow/view/board_detail_screen.dart';
// 컬럼 탭 + PageView 페이징 컨테이너
//
// [구조 하이라키]
// _BoardColumnsView
// └─ _BoardColumnsViewState
//    ├─ BoardDetailColumnTabsBar
//    └─ PageView.builder -> _ColumnView

/// 컬럼 탭과 페이지 전환 영역을 묶는 컨테이너.
class _BoardColumnsView extends StatefulWidget {
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
  State<_BoardColumnsView> createState() => _BoardColumnsViewState();
}

class _BoardColumnsViewState extends State<_BoardColumnsView> {
  late final PageController _pageController;
  int _currentIndex = 0;

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

  /// 컬럼 탭 바와 페이지 본문을 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final columns = widget.detail.columns;

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
          isOwner: widget.isOwner,
          manageButton: _ColumnManageButton(boardId: widget.boardId, columns: columns),
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
              final cards = merged
                  .where((c) => c.columnId == col.id)
                  .toList()
                ..sort((a, b) => a.position.compareTo(b.position));
              final cardsKey = cards.map((c) => '${c.id}:${c.position}').join(',');
              return _ColumnView(
                key: ValueKey('col_${col.id}_$cardsKey'),
                column: col,
                cards: cards,
                columns: columns,
                boardId: widget.boardId,
                onRefresh: widget.onRefresh,
              );
            },
          ),
        ),
      ],
    );
  }
}
