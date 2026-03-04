// board_detail_screen.dart
// 보드 상세 (PageView 1컬럼, 세로 스크롤)
//
// [구조 하이라키]
// BoardDetailScreen(엔트리/조립)
// ├─ BoardDetailHeader(상단 헤더 위젯)
// ├─ _BoardWsBridge(part: board_detail_screen_ws.dart)
// ├─ _BoardColumnsView(part: board_detail_columns_pager.dart)
// ├─ 보드 액션(part: board_detail_actions_*.dart)
// └─ 컬럼/카드 UI(part: board_detail_columns_*.dart)

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/vm/card_handler.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/markdown_input_formatter.dart';
import 'package:syncflow/vm/board_detail_notifier.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/vm/ws_service_notifier.dart';
import 'package:syncflow/vm/board_handler.dart';
import 'package:syncflow/widget/card_detail_modal.dart';
import 'package:syncflow/widget/markdown_help_dialog.dart';
import 'package:syncflow/widget/card_tile.dart';
import 'package:syncflow/widget/move_card_sheet.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';
import 'package:syncflow/widget/board_detail_header.dart';
import 'package:syncflow/vm/board_list_notifier.dart';

part 'board_detail/board_detail_screen_ws.dart';
part 'board_detail/board_detail_actions_menu.dart';
part 'board_detail/board_detail_actions_invite.dart';
part 'board_detail/board_detail_actions_presence.dart';
part 'board_detail/board_detail_columns_pager.dart';
part 'board_detail/board_detail_columns_manage.dart';
part 'board_detail/board_detail_columns_column_view.dart';

/// 보드 상세 화면
class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({
    super.key,
    required this.boardId,
    required this.title,
    this.ownerId,
    this.initialCardId,
  });

  final int boardId;
  final String title;
  final int? ownerId;
  final int? initialCardId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late String _title;
  int? _pendingOpenCardId;

  /// 최초 진입 시 전달받은 제목으로 로컬 표시 제목을 초기화한다.
  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _pendingOpenCardId = widget.initialCardId;
  }

  /// 라우팅 교체 등으로 위젯 제목이 바뀌면 로컬 표시 제목도 동기화한다.
  @override
  void didUpdateWidget(covariant BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _title = widget.title;
    }
    if (oldWidget.initialCardId != widget.initialCardId &&
        widget.initialCardId != null) {
      _pendingOpenCardId = widget.initialCardId;
    }
  }

  void _tryOpenCardFromPush(BoardDetail detail, {required bool clearIfMissing}) {
    final targetId = _pendingOpenCardId;
    if (targetId == null) return;

    CardItem? targetCard;
    for (final card in detail.cards) {
      if (card.id == targetId) {
        targetCard = card;
        break;
      }
    }

    if (targetCard == null) {
      if (clearIfMissing) {
        _pendingOpenCardId = null;
      }
      return;
    }

    _pendingOpenCardId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => CardDetailModal(
          card: targetCard!,
          boardId: widget.boardId,
          onRefresh: () => ref.invalidate(boardDetailProvider(widget.boardId)),
        ),
      );
    });
  }

  /// 보드 상세 화면의 전체 조립 지점:
  /// 헤더, 로딩/에러 처리, WS 브리지, 컬럼 뷰를 연결한다.
  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(boardDetailProvider(widget.boardId));
    final cachedDetail = ref.watch(boardDetailCacheProvider(widget.boardId));
    final titleOverride = ref.watch(boardTitleOverrideProvider(widget.boardId));
    final session = ref.watch(sessionNotifierProvider).value;
    final detail = cachedDetail ?? detailAsync.value;
    final resolvedOwnerId = widget.ownerId ?? detail?.ownerId;
    final isOwner = resolvedOwnerId != null && session?.userId == resolvedOwnerId;
    final displayTitle = titleOverride ?? detail?.title ?? _title;

    return Scaffold(
      backgroundColor: context.appTheme.background,
      appBar: AppBar(
        backgroundColor: context.appTheme.background,
        scrolledUnderElevation: 0,
        toolbarHeight: 96,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleSpacing: 0,
        title: BoardDetailHeader(
          title: displayTitle,
          isOwner: isOwner,
          onBack: () => CustomNavigationUtil.back(context),
          menuButton: _BoardMenuButton(
            boardId: widget.boardId,
            currentTitle: displayTitle,
            onTitleChanged: (newTitle) {
              setState(() => _title = newTitle);
              ref.read(boardTitleOverrideProvider(widget.boardId).notifier).state = newTitle;
            },
          ),
          presenceRowChildren: [
            if (isOwner) _InviteButton(boardId: widget.boardId),
            _PresenceAvatarsButton(boardId: widget.boardId),
            const _WsConnectionIndicator(),
          ],
        ),
      ),
      body: detailAsync.when(
        loading: () {
          final prev = detail;
          if (prev != null && prev.columns.isNotEmpty) {
            _tryOpenCardFromPush(prev, clearIfMissing: false);
            return _BoardWsBridge(
              boardId: widget.boardId,
              child: _BoardColumnsView(
                detail: prev,
                boardId: widget.boardId,
                isOwner: isOwner,
                onRefresh: () => ref.invalidate(boardDetailProvider(widget.boardId)),
                optimisticMoves: ref.watch(optimisticCardMovesProvider(widget.boardId)),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${context.tr('error')}: $e', style: TextStyle(color: context.appTheme.accent)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(boardDetailProvider(widget.boardId)),
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
        data: (detail) {
          final effective = cachedDetail ?? detail;
          if (effective == null || effective.columns.isEmpty) {
            return Center(child: Text(context.tr('boardLoadFailed')));
          }
          _tryOpenCardFromPush(effective, clearIfMissing: true);
          return _BoardWsBridge(
            boardId: widget.boardId,
            child: _BoardColumnsView(
              detail: effective,
              boardId: widget.boardId,
              isOwner: isOwner,
              onRefresh: () => ref.invalidate(boardDetailProvider(widget.boardId)),
              optimisticMoves: ref.watch(optimisticCardMovesProvider(widget.boardId)),
            ),
          );
        },
      ),
    );
  }
}
