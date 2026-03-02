// board_list_screen.dart
// 보드 목록 (대시보드)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/view/board_detail_screen.dart';
import 'package:syncflow/vm/board_list_notifier.dart';
import 'package:syncflow/vm/session_notifier.dart';

/// 보드 목록 화면
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  /// 보드 참가 다이얼로그 (MainScaffold 앱바 등에서 호출)
  static Future<void> showBoardJoinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => KeyboardDismissScrollView(
        child: Padding(
          padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.tr('boardJoin'),
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeSubtitle,
                  fontWeight: FontWeight.bold,
                  color: ctx.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: ctx.tr('inviteCodePlaceholder'),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _doJoinBoard(context, ref, controller.text, ctx),
                child: Text(ctx.tr('join')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _doJoinBoard(
    BuildContext context,
    WidgetRef ref,
    String code,
    BuildContext sheetContext,
  ) async {
    if (code.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('inviteCodeRequired'))),
      );
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final res = await ref.read(boardListNotifierProvider.notifier).joinBoard(code);
      if (res != null && context.mounted) {
        CustomNavigationUtil.to(
          context,
          BoardDetailScreen(boardId: res.boardId, title: res.title, ownerId: null),
        );
        if (res.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message!)));
        }
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// 보드 생성 다이얼로그 (MainScaffold 앱바 등에서 호출)
  static Future<void> showBoardCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String selectedTemplate = 'todo';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return KeyboardDismissScrollView(
            child: Padding(
              padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.tr('boardNew'),
                    style: TextStyle(
                      fontSize: ConfigUI.fontSizeSubtitle,
                      fontWeight: FontWeight.bold,
                      color: ctx.appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: ctx.tr('boardTitle'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ctx.tr('template'),
                    style: TextStyle(
                      fontSize: ConfigUI.fontSizeLabel,
                      color: ctx.appTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(ctx.tr('templateTodo')),
                        selected: selectedTemplate == 'todo',
                        onSelected: (_) => setModalState(() => selectedTemplate = 'todo'),
                      ),
                      ChoiceChip(
                        label: Text(ctx.tr('templateSimple')),
                        selected: selectedTemplate == 'simple',
                        onSelected: (_) => setModalState(() => selectedTemplate = 'simple'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _doCreateBoard(context, ref, controller.text, selectedTemplate, ctx),
                    child: Text(ctx.tr('create')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _doCreateBoard(
    BuildContext context,
    WidgetRef ref,
    String title,
    String template,
    BuildContext sheetContext,
  ) async {
    if (title.trim().isEmpty) return;
    Navigator.pop(sheetContext);
    try {
      final board = await ref.read(boardListNotifierProvider.notifier).createBoard(
        title.trim(),
        template: template,
      );
      if (board != null && context.mounted) {
        CustomNavigationUtil.to(
          context,
          BoardDetailScreen(boardId: board.id, title: board.title, ownerId: board.ownerId),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardListNotifierProvider);

    return boardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${context.tr('error')}: $e', style: TextStyle(color: context.appTheme.accent)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(boardListNotifierProvider.notifier).refresh(),
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
      data: (boards) => _BoardListContent(boards: boards),
    );
  }
}

class _BoardListContent extends ConsumerStatefulWidget {
  const _BoardListContent({required this.boards});

  final List<BoardItem> boards;

  @override
  ConsumerState<_BoardListContent> createState() => _BoardListContentState();
}

class _BoardListContentState extends ConsumerState<_BoardListContent> {
  _BoardFilter _filter = _BoardFilter.all;

  bool _isMyBoard(BoardItem board, int? myUserId) {
    if (myUserId == null) return false;
    return board.ownerId == myUserId;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final myUserId = ref.watch(sessionNotifierProvider).value?.userId;
    final filteredBoards = widget.boards.where((b) {
      switch (_filter) {
        case _BoardFilter.mine:
          return _isMyBoard(b, myUserId);
        case _BoardFilter.member:
          return !_isMyBoard(b, myUserId);
        case _BoardFilter.all:
          return true;
      }
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(ConfigUI.screenPaddingH),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => BoardListScreen.showBoardJoinDialog(context, ref),
                  icon: const Icon(Icons.group_add, size: 20),
                  label: Text(context.tr('boardJoin')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => BoardListScreen.showBoardCreateDialog(context, ref),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(context.tr('boardNew')),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.tr('myBoards')),
                  selected: _filter == _BoardFilter.mine,
                  onSelected: (_) => setState(() => _filter = _BoardFilter.mine),
                ),
                ChoiceChip(
                  label: Text(context.tr('memberBoards')),
                  selected: _filter == _BoardFilter.member,
                  onSelected: (_) => setState(() => _filter = _BoardFilter.member),
                ),
                ChoiceChip(
                  label: Text(context.tr('all')),
                  selected: _filter == _BoardFilter.all,
                  onSelected: (_) => setState(() => _filter = _BoardFilter.all),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (filteredBoards.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined, size: 64, color: p.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _filter == _BoardFilter.mine
                        ? context.tr('noMyBoards')
                        : _filter == _BoardFilter.member
                            ? context.tr('noMemberBoards')
                            : context.tr('noBoards'),
                    style: TextStyle(fontSize: ConfigUI.fontSizeBody, color: p.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => BoardListScreen.showBoardCreateDialog(context, ref),
                    child: Text(context.tr('firstBoardCreate')),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final b = filteredBoards[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BoardTile(
                      board: b,
                      onTap: () => CustomNavigationUtil.to(
                        context,
                        BoardDetailScreen(boardId: b.id, title: b.title, ownerId: b.ownerId),
                      ),
                    ),
                  );
                },
                childCount: filteredBoards.length,
              ),
            ),
          ),
      ],
    );
  }
}

enum _BoardFilter { mine, member, all }

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.board, required this.onTap});

  final BoardItem board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Material(
      color: p.cardBackground,
      borderRadius: ConfigUI.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: ConfigUI.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(ConfigUI.paddingCard),
          decoration: BoxDecoration(
            borderRadius: ConfigUI.cardRadius,
            border: Border.all(color: p.divider, width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.dashboard, color: p.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  board.title,
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeBody,
                    fontWeight: FontWeight.w500,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
