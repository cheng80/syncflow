// board_list_screen.dart
// 보드 목록 (대시보드)
//
// [구조 하이라키]
// BoardListScreen(엔트리)
// └─ _BoardListContent
//    ├─ BoardListActionsRow(widget)
//    ├─ BoardListFilterChips(widget)
//    └─ _BoardTile(보드 카드)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';
import 'package:syncflow/widget/board_list_controls.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/view/board_detail_screen.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/tutorial_keys.dart';
import 'package:syncflow/vm/board_list_notifier.dart';
import 'package:syncflow/vm/session_notifier.dart';

/// 보드 목록 화면
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key, this.tutorialKeys});

  /// ShowcaseView 튜토리얼용 키 (MainScaffold에서 전달)
  final TutorialKeys? tutorialKeys;

  /// 보드 참가 다이얼로그 (MainScaffold 앱바 등에서 호출)
  /// 보드 참가 코드 입력 시트를 연다.
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

  /// 보드 참가 요청을 수행하고 성공 시 상세 화면으로 이동한다.
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
  /// 보드 생성 시트를 연다.
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

  static bool _isCreatingTutorial = false;

  /// 첫 설치 사용자용 튜토리얼 보드/샘플 카드를 자동 생성한다.
  static Future<void> _createTutorialBoardOnFirstInstall(BuildContext context, WidgetRef ref) async {
    if (AppStorage.hasTutorialBoardCreated || _isCreatingTutorial) return;
    _isCreatingTutorial = true;
    try {
      await ref.read(boardListNotifierProvider.notifier).ensureTutorialBoardWithSamples(
        cardsPerColumn: 1,
      );
      await AppStorage.setTutorialBoardCreated(); // 성공 후에만 플래그 설정
      await ref.read(boardListNotifierProvider.notifier).refresh();
    } catch (_) {
      // 실패 시 플래그 미설정 → 재시도 가능 (튜토리얼 보드가 있어도 카드 없으면 재실행됨)
    } finally {
      _isCreatingTutorial = false;
    }
  }

  /// 보드 생성 요청을 수행하고 성공 시 상세 화면으로 이동한다.
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

  /// 보드 목록 로딩/에러/데이터 상태를 분기 렌더링한다.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardListNotifierProvider);

    ref.listen(boardListNotifierProvider, (prev, next) {
      next.whenData((boards) {
        final hasTutorial = boards.any((b) => b.title == BoardListNotifier.tutorialBoardTitle);
        final shouldCreate = (boards.isEmpty || hasTutorial) &&
            !AppStorage.hasTutorialBoardCreated &&
            ref.read(sessionNotifierProvider).value?.sessionToken != null;
        if (shouldCreate) {
          _createTutorialBoardOnFirstInstall(context, ref);
        }
      });
    });

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
      data: (boards) => _BoardListContent(boards: boards, tutorialKeys: tutorialKeys),
    );
  }
}

class _BoardListContent extends ConsumerStatefulWidget {
  const _BoardListContent({required this.boards, this.tutorialKeys});

  final List<BoardItem> boards;
  final TutorialKeys? tutorialKeys;

  @override
  ConsumerState<_BoardListContent> createState() => _BoardListContentState();
}

class _BoardListContentState extends ConsumerState<_BoardListContent> {
  _BoardFilter _filter = _BoardFilter.all;

  /// 현재 로그인 사용자가 해당 보드의 소유자인지 판별한다.
  bool _isMyBoard(BoardItem board, int? myUserId) {
    if (myUserId == null) return false;
    return board.ownerId == myUserId;
  }

  /// 필터/액션/리스트를 포함한 보드 목록 본문을 렌더링한다.
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
            child: BoardListActionsRow(
              joinShowcaseKey: widget.tutorialKeys?.join,
              createShowcaseKey: widget.tutorialKeys?.create,
              joinDescription: context.tr('tutorial_step_3'),
              createDescription: context.tr('tutorial_step_4'),
              joinLabel: context.tr('boardJoin'),
              createLabel: context.tr('boardNew'),
              onJoin: () => BoardListScreen.showBoardJoinDialog(context, ref),
              onCreate: () => BoardListScreen.showBoardCreateDialog(context, ref),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
            child: BoardListFilterChips(
              showcaseKey: widget.tutorialKeys?.filter,
              description: context.tr('tutorial_step_5'),
              mineLabel: context.tr('myBoards'),
              memberLabel: context.tr('memberBoards'),
              allLabel: context.tr('all'),
              isMineSelected: _filter == _BoardFilter.mine,
              isMemberSelected: _filter == _BoardFilter.member,
              isAllSelected: _filter == _BoardFilter.all,
              onMineSelected: () => setState(() => _filter = _BoardFilter.mine),
              onMemberSelected: () => setState(() => _filter = _BoardFilter.member),
              onAllSelected: () => setState(() => _filter = _BoardFilter.all),
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
                  final isMyBoard = _isMyBoard(b, myUserId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BoardTile(
                      board: b,
                      isMyBoard: isMyBoard,
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
  const _BoardTile({
    required this.board,
    required this.isMyBoard,
    required this.onTap,
  });

  final BoardItem board;
  final bool isMyBoard;
  final VoidCallback onTap;

  /// 보드 유형(내 보드/참여 보드)별 컬러 토큰을 적용해 카드를 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final borderColor = isMyBoard ? p.boardMineBorder : p.boardMemberBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ConfigUI.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(ConfigUI.paddingCard),
          decoration: BoxDecoration(
            color: p.cardBackground,
            borderRadius: ConfigUI.cardRadius,
            border: Border.all(color: borderColor, width: ConfigUI.borderWidthBrutal),
            boxShadow: ConfigUI.shadowOffsetBrutalCard(borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.dashboard, color: borderColor, size: 28),
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
              Icon(Icons.chevron_right, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }
}
