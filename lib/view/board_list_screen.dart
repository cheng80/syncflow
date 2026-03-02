// board_list_screen.dart
// 보드 목록 (대시보드)

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

/// 보드 목록 화면
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardListNotifierProvider);

    return boardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('오류: $e', style: TextStyle(color: context.appTheme.accent)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(boardListNotifierProvider.notifier).refresh(),
              child: const Text('다시 시도'),
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
  void _showCreateDialog() {
    final controller = TextEditingController();
    String selectedTemplate = 'todo';
    showModalBottomSheet(
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
                    '새 보드',
                    style: TextStyle(
                      fontSize: ConfigUI.fontSizeSubtitle,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '보드 제목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '템플릿',
                    style: TextStyle(
                      fontSize: ConfigUI.fontSizeLabel,
                      color: context.appTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('할 일 / 진행 중 / 완료'),
                        selected: selectedTemplate == 'todo',
                        onSelected: (_) => setModalState(() => selectedTemplate = 'todo'),
                      ),
                      ChoiceChip(
                        label: const Text('간단 (단일 컬럼)'),
                        selected: selectedTemplate == 'simple',
                        onSelected: (_) => setModalState(() => selectedTemplate = 'simple'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _createBoard(controller.text, selectedTemplate, ctx),
                    child: const Text('생성'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
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
                '보드 참가',
                style: TextStyle(
                  fontSize: ConfigUI.fontSizeSubtitle,
                  fontWeight: FontWeight.bold,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: '6자리 초대 코드',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _joinBoard(controller.text, ctx),
                child: const Text('참가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinBoard(String code, BuildContext ctx) async {
    if (code.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 초대 코드를 입력하세요')),
      );
      return;
    }
    CustomNavigationUtil.back(ctx);
    try {
      final res = await ref.read(boardListNotifierProvider.notifier).joinBoard(code);
      if (res != null && mounted) {
        CustomNavigationUtil.to(
          context,
          BoardDetailScreen(boardId: res.boardId, title: res.title, ownerId: null),
        );
        if (res.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message!)));
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _createBoard(String title, String template, BuildContext ctx) async {
    if (title.trim().isEmpty) return;
    CustomNavigationUtil.back(ctx);
    try {
      final board = await ref.read(boardListNotifierProvider.notifier).createBoard(
        title.trim(),
        template: template,
      );
      if (board != null && mounted) {
        CustomNavigationUtil.to(
          context,
          BoardDetailScreen(boardId: board.id, title: board.title, ownerId: board.ownerId),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(ConfigUI.screenPaddingH),
            child: Row(
              children: [
                Text(
                  '내 보드',
                  style: TextStyle(
                    fontSize: ConfigUI.fontSizeTitle,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _showJoinDialog,
                  icon: const Icon(Icons.group_add, size: 20),
                  label: const Text('보드 참가'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('새 보드'),
                ),
              ],
            ),
          ),
        ),
        if (widget.boards.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined, size: 64, color: p.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    '보드가 없습니다',
                    style: TextStyle(fontSize: ConfigUI.fontSizeBody, color: p.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showCreateDialog,
                    child: const Text('첫 보드 만들기'),
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
                  final b = widget.boards[index];
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
                childCount: widget.boards.length,
              ),
            ),
          ),
      ],
    );
  }
}

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
