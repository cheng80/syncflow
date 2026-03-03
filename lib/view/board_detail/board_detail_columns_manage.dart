part of 'package:syncflow/view/board_detail_screen.dart';
// 컬럼 관리 버튼/시트(추가/수정/삭제/정렬)
//
// [구조 하이라키]
// _ColumnManageButton
// └─ _ColumnManageSheet
//    ├─ 토큰/재조회 유틸
//    ├─ 추가/수정/삭제/이동 액션
//    └─ 정렬 리스트 UI

/// 컬럼 관리 시트를 여는 액션 버튼.
class _ColumnManageButton extends ConsumerStatefulWidget {
  const _ColumnManageButton({
    required this.boardId,
    required this.columns,
  });

  final int boardId;
  final List<ColumnItem> columns;

  @override
  ConsumerState<_ColumnManageButton> createState() => _ColumnManageButtonState();
}

class _ColumnManageButtonState extends ConsumerState<_ColumnManageButton> {
  /// 컬럼 관리 바텀시트를 연다.
  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColumnManageSheet(
        boardId: widget.boardId,
        initialColumns: widget.columns,
        onChanged: () {
          ref.invalidate(boardDetailProvider(widget.boardId));
        },
      ),
    );
  }

  /// 버튼 UI 렌더링.
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _openSheet,
      icon: const Icon(Icons.tune, size: 18),
      label: Text(context.tr('columnManage')),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

/// 컬럼 추가/수정/삭제/순서 변경을 처리하는 시트.
class _ColumnManageSheet extends ConsumerStatefulWidget {
  const _ColumnManageSheet({
    required this.boardId,
    required this.initialColumns,
    required this.onChanged,
  });

  final int boardId;
  final List<ColumnItem> initialColumns;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ColumnManageSheet> createState() => _ColumnManageSheetState();
}

class _ColumnManageSheetState extends ConsumerState<_ColumnManageSheet> {
  static const int _columnTitleMaxLength = 40;
  late List<ColumnItem> _columns;
  bool _loading = false;

  /// 초기 컬럼 목록을 정렬해 로컬 상태로 세팅한다.
  @override
  void initState() {
    super.initState();
    _columns = List<ColumnItem>.from(widget.initialColumns)
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// 세션 토큰을 확인하고, 없으면 사용자에게 만료 안내를 보여준다.
  Future<String?> _requireToken() async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('sessionExpired'))));
    }
    return token;
  }

  /// 서버 기준 최신 컬럼 목록으로 다시 동기화한다.
  Future<void> _reloadColumns() async {
    ref.invalidate(boardDetailProvider(widget.boardId));
    final detail = await ref.read(boardDetailProvider(widget.boardId).future);
    if (!mounted) return;
    if (detail == null) return;
    setState(() {
      _columns = List<ColumnItem>.from(detail.columns)
        ..sort((a, b) => a.position.compareTo(b.position));
    });
    ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = detail;
  }

  /// 컬럼 제목 입력 다이얼로그를 공통으로 띄운다.
  Future<String?> _showTitleInputDialog({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: _columnTitleMaxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: context.tr('columnTitle'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => CustomNavigationUtil.back(ctx),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: controller.text.trim()),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  /// 공통 실행 래퍼: 로딩/예외/재조회 처리를 일관되게 수행한다.
  Future<void> _runColumnTask(Future<void> Function(String token) task) async {
    final token = await _requireToken();
    if (token == null) return;
    setState(() => _loading = true);
    try {
      await task(token);
      await _reloadColumns();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 새 컬럼을 생성한다.
  Future<void> _addColumn() async {
    final title = await _showTitleInputDialog(title: context.tr('columnAdd'));
    if (title == null || title.isEmpty) return;
    await _runColumnTask((token) async {
      await ref.read(boardHandlerProvider).createColumn(
            token,
            widget.boardId,
            title: title,
          );
    });
  }

  /// 선택한 컬럼의 제목을 변경한다.
  Future<void> _renameColumn(ColumnItem column) async {
    final title = await _showTitleInputDialog(
      title: context.tr('columnRename'),
      initial: column.title,
    );
    if (title == null || title.isEmpty) return;
    await _runColumnTask((token) async {
      await ref.read(boardHandlerProvider).updateColumn(
            token,
            widget.boardId,
            column.id,
            title: title,
          );
    });
  }

  // ignore: unused_element - isDone 스위치 임시 숨김 시 사용
  /// 컬럼 완료 상태(is_done)를 토글한다. (현재 UI 미노출)
  Future<void> _toggleDone(ColumnItem column, bool nextDone) async {
    await _runColumnTask((token) async {
      await ref.read(boardHandlerProvider).updateColumn(
            token,
            widget.boardId,
            column.id,
            isDone: nextDone,
          );
    });
  }

  /// 컬럼을 좌/우(혹은 상/하)로 이동시켜 순서를 변경한다.
  Future<void> _moveColumn(int index, int direction) async {
    final next = index + direction;
    if (next < 0 || next >= _columns.length) return;
    final basePos = _columns[next].position;
    final targetPos = direction < 0 ? basePos - 1 : basePos + 1;
    final col = _columns[index];
    await _runColumnTask((token) async {
      await ref.read(boardHandlerProvider).updateColumn(
            token,
            widget.boardId,
            col.id,
            position: targetPos,
          );
    });
  }

  /// 컬럼 삭제 확인 후 삭제를 수행한다.
  Future<void> _deleteColumn(ColumnItem column) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('columnDelete')),
        content: Text(context.tr('columnDeleteConfirm', namedArgs: {'name': column.title})),
        actions: [
          TextButton(
            onPressed: () => CustomNavigationUtil.back(ctx, result: false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => CustomNavigationUtil.back(ctx, result: true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _runColumnTask((token) async {
      await ref.read(boardHandlerProvider).deleteColumn(
            token,
            widget.boardId,
            column.id,
          );
    });
  }

  /// 컬럼 관리 시트 UI를 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.tr('columnManage'),
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeSubtitle,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _addColumn,
                  tooltip: context.tr('columnAdd'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_columns.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.tr('noColumns'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _columns.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final col = _columns[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.cardBackground,
                        borderRadius: ConfigUI.cardRadius,
                        border: Border.all(color: p.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  col.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ConfigUI.fontSizeBody,
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  col.isDone ? context.tr('columnDone') : context.tr('columnProgress'),
                                  style: TextStyle(
                                    fontSize: ConfigUI.fontSizeCaption,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: (_loading || index == 0) ? null : () => _moveColumn(index, -1),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            tooltip: context.tr('moveUp'),
                          ),
                          IconButton(
                            onPressed: (_loading || index == _columns.length - 1) ? null : () => _moveColumn(index, 1),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            tooltip: context.tr('moveDown'),
                          ),
                          IconButton(
                            onPressed: _loading ? null : () => _renameColumn(col),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: context.tr('rename'),
                          ),
                          // TODO: 임시로 isDone 스위치 숨김
                          // Switch(
                          //   value: col.isDone,
                          //   onChanged: _loading ? null : (v) => _toggleDone(col, v),
                          // ),
                          IconButton(
                            onPressed: _loading ? null : () => _deleteColumn(col),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: p.accent,
                            tooltip: context.tr('delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => CustomNavigationUtil.back(context),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보드 메뉴 (이름 수정, 삭제) - owner만 표시
