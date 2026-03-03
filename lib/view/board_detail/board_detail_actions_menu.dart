part of 'package:syncflow/view/board_detail_screen.dart';
// 보드 메뉴(이름 변경/삭제)
//
// [구조 하이라키]
// _BoardMenuButton
// ├─ _renameBoard
// └─ _deleteBoard

/// 헤더 우측 메뉴 버튼:
/// 보드 이름 변경/삭제 동작을 제공한다.
class _BoardMenuButton extends ConsumerWidget {
  const _BoardMenuButton({
    required this.boardId,
    required this.currentTitle,
    required this.onTitleChanged,
  });

  final int boardId;
  final String currentTitle;
  final void Function(String) onTitleChanged;

  /// 보드 이름 변경 다이얼로그를 띄우고 서버 반영 후 목록/상세를 갱신한다.
  Future<void> _renameBoard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('boardRename')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: context.tr('boardTitle'),
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
    if (newTitle == null || newTitle.isEmpty) return;

    try {
      await ref.read(boardListNotifierProvider.notifier).updateBoard(boardId, newTitle);
      ref.invalidate(boardDetailProvider(boardId));
      if (context.mounted) {
        onTitleChanged(newTitle);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// 삭제 확인 후 보드를 삭제한다.
  /// 실제 화면 이탈은 BOARD_DELETED 브로드캐스트 수신 시 처리된다.
  Future<void> _deleteBoard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('boardDelete')),
        content: Text(context.tr('boardDeleteConfirm')),
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

    try {
      await ref.read(boardListNotifierProvider.notifier).deleteBoard(boardId);
      // BOARD_DELETED WebSocket 브로드캐스트로 _BoardWsBridge에서 back() 처리됨
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// 메뉴 UI 렌더링 및 액션 라우팅.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: context.appTheme.icon),
      onSelected: (value) {
        if (value == 'rename') {
          _renameBoard(context, ref);
        } else if (value == 'delete') {
          _deleteBoard(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(context.tr('boardRename'))),
        PopupMenuItem(
          value: 'delete',
          child: Text(context.tr('boardDelete'), style: TextStyle(color: context.appTheme.accent)),
        ),
      ],
    );
  }
}

/// 초대 코드 생성 및 공유 버튼 (owner만 표시)
