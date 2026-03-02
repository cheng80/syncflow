// board_detail_screen.dart
// 보드 상세 (PageView 1컬럼, 세로 스크롤)

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
import 'package:syncflow/vm/board_list_notifier.dart';

/// 보드 상세 화면
class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({
    super.key,
    required this.boardId,
    required this.title,
    this.ownerId,
  });

  final int boardId;
  final String title;
  final int? ownerId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
  }

  @override
  void didUpdateWidget(covariant BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _title = widget.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(boardDetailProvider(widget.boardId));
    final cachedDetail = ref.watch(boardDetailCacheProvider(widget.boardId));
    final session = ref.watch(sessionNotifierProvider).value;
    final detail = cachedDetail ?? detailAsync.value;
    final resolvedOwnerId = widget.ownerId ?? detail?.ownerId;
    final isOwner = resolvedOwnerId != null && session?.userId == resolvedOwnerId;

    return Scaffold(
      backgroundColor: context.appTheme.background,
      appBar: AppBar(
        backgroundColor: context.appTheme.background,
        scrolledUnderElevation: 0,
        toolbarHeight: 96,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1행: 뒤로가기 + 제목(가운데) + 삭제/이름변경 메뉴
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => CustomNavigationUtil.back(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _title,
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontSize: ConfigUI.fontSizeAppBar,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (isOwner)
                    _BoardMenuButton(
                      boardId: widget.boardId,
                      currentTitle: _title,
                      onTitleChanged: (newTitle) => setState(() => _title = newTitle),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              // 2행: 초대, 접속자, 연결상태
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isOwner) _InviteButton(boardId: widget.boardId),
                  _PresenceAvatarsButton(boardId: widget.boardId),
                  const _WsConnectionIndicator(),
                ],
              ),
            ],
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () {
          final prev = detail;
          if (prev != null && prev.columns.isNotEmpty) {
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

/// 컬럼 탭 + PageView (앞/뒤 컬럼 표시)
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.detail.columns;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ConfigUI.screenPaddingH,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(columns.length, (index) {
                      return _ColumnTab(
                        label: columns[index].title,
                        isSelected: _currentIndex == index,
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: ConfigUI.durationMedium,
                          curve: Curves.easeInOut,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              if (widget.isOwner) ...[
                const SizedBox(width: 8),
                _ColumnManageButton(boardId: widget.boardId, columns: columns),
              ],
            ],
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

class _ColumnTab extends StatelessWidget {
  const _ColumnTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ConfigUI.durationShort,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? p.primary.withValues(alpha: 0.2)
                : p.cardBackground,
            borderRadius: ConfigUI.chipRadius,
            border: Border.all(
              color: isSelected ? p.primary : p.textSecondary.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? p.primary : p.textSecondary,
              fontSize: ConfigUI.fontSizeLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// 보드 진입 시 JOIN_BOARD, 이탈 시 LEAVE_BOARD
class _BoardWsBridge extends ConsumerStatefulWidget {
  const _BoardWsBridge({required this.boardId, required this.child});

  final int boardId;
  final Widget child;

  @override
  ConsumerState<_BoardWsBridge> createState() => _BoardWsBridgeState();
}

class _BoardWsBridgeState extends ConsumerState<_BoardWsBridge> {
  late final dynamic _wsService;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<bool>? _connSub;
  bool _needsRejoin = false;

  @override
  void initState() {
    super.initState();
    _wsService = ref.read(wsServiceProvider);
    joinBoardRoom(ref, widget.boardId);
    _msgSub = _wsService.messages.listen(_onWsMessage);
    _connSub = _wsService.connectionState.listen((connected) async {
      if (!mounted) return;
      if (!connected) {
        _needsRejoin = true;
        return;
      }
      if (_needsRejoin) {
        _needsRejoin = false;
        await _wsService.joinBoard(widget.boardId);
        if (mounted) {
          ref.invalidate(boardDetailProvider(widget.boardId));
        }
      }
    });
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;

    if (type == 'BOARD_JOINED' && data != null) {
      _applyBoardJoined(data);
      return;
    }
    if (type == 'PRESENCE_JOINED' && data != null) {
      _applyPresenceJoined(data);
      return;
    }
    if (type == 'PRESENCE_LEFT' && data != null) {
      _applyPresenceLeft(data);
      return;
    }
    if (type == 'BOARD_DELETED' && data != null) {
      final bid = (data['board_id'] as num?)?.toInt();
      if (bid == widget.boardId && mounted) {
        ref.read(boardListNotifierProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('boardDeletedByOwner'))),
          );
          CustomNavigationUtil.back(context);
        }
      }
      return;
    }
    if (type == 'CARD_LOCKED' && data != null) {
      _applyCardLocked(data);
      return;
    }
    if (type == 'CARD_UNLOCKED' && data != null) {
      _applyCardUnlocked(data);
      return;
    }

    if (type == 'ERROR') {
      final reqId = msg['req_id'] as String?;
      final message = (data?['message'] as String?) ?? context.tr('syncError');
      final code = data?['code'] as String?;
      final detail = data?['detail'] as Map<String, dynamic>?;
      if (reqId != null) {
        final pendingReqIds = Set<String>.from(
          ref.read(pendingMoveReqIdsProvider(widget.boardId)),
        )..remove(reqId);
        ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state = pendingReqIds;

        final retryMap = Map<String, int>.from(
          ref.read(pendingMoveRetryCountProvider(widget.boardId)),
        )..remove(reqId);
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = retryMap;
      }
      if (code == 'LOCKED' && detail != null) {
        final cardId = (detail['card_id'] as num?)?.toInt();
        final lockedByUserId = (detail['locked_by_user_id'] as num?)?.toInt();
        final lockedByDisplay = detail['locked_by_display'] as String?;
        final expiresAt = (detail['expires_at'] as num?)?.toInt();
        if (cardId != null &&
            lockedByUserId != null &&
            lockedByDisplay != null &&
            expiresAt != null) {
          final locks = Map<int, CardLockState>.from(
            ref.read(cardLocksProvider(widget.boardId)),
          );
          locks[cardId] = CardLockState(
            cardId: cardId,
            lockedByUserId: lockedByUserId,
            lockedByDisplay: lockedByDisplay,
            expiresAt: expiresAt,
          );
          ref.read(cardLocksProvider(widget.boardId).notifier).state = locks;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    if (data == null) return;
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final incomingVersion = (data['board_version'] as num?)?.toInt();
    final currentVersion = ref.read(boardVersionProvider(widget.boardId));
    if (incomingVersion != null && currentVersion != null && incomingVersion < currentVersion) {
      debugPrint('[동기화] 구버전 이벤트 무시: incoming=$incomingVersion current=$currentVersion type=$type');
      return;
    }
    if (incomingVersion != null &&
        (currentVersion == null || incomingVersion > currentVersion)) {
      ref.read(boardVersionProvider(widget.boardId).notifier).state = incomingVersion;
    }

    const cardTypes = [
      'CARD_CREATED', 'CARD_MOVED', 'CARD_UPDATED',
      'CARD_ARCHIVED', 'CARD_RESTORED',
    ];
    if (cardTypes.contains(type)) {
      final reqId = msg['req_id'] as String?;
      final pendingReqIds = ref.read(pendingMoveReqIdsProvider(widget.boardId));
      final isAckForMyMove = type == 'CARD_MOVED' && reqId != null && pendingReqIds.contains(reqId);

      if (isAckForMyMove) {
        final nextPending = Set<String>.from(pendingReqIds)..remove(reqId);
        ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state = nextPending;
        final retryMap = Map<String, int>.from(
          ref.read(pendingMoveRetryCountProvider(widget.boardId)),
        )..remove(reqId);
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = retryMap;
        _applyCardMoved(data);
        return;
      }

      if (type == 'CARD_MOVED') {
        _applyCardMoved(data);
        return;
      }

      if (type == 'CARD_CREATED') {
        _applyCardCreated(data);
        return;
      }
      if (type == 'CARD_UPDATED') {
        _applyCardUpdated(data);
        return;
      }
      if (type == 'CARD_ARCHIVED') {
        _applyCardArchived(data);
        return;
      }
      if (type == 'CARD_RESTORED') {
        ref.invalidate(boardDetailProvider(widget.boardId));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardDetailProvider(widget.boardId), (prev, next) {
      if (!next.isLoading && next.value != null) {
        final detail = next.value!;
        // build 단계 중 provider state 변경을 피하기 위해 프레임 이후 반영
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final pendingReqIds = ref.read(pendingMoveReqIdsProvider(widget.boardId));
          if (pendingReqIds.isNotEmpty) {
            // 아직 ACK 대기 중인 이동이 있으면 낙관적 상태 유지
            return;
          }
          ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = detail;
          ref.read(boardVersionProvider(widget.boardId).notifier).state = detail.boardVersion;
          final hadMoves = ref.read(optimisticCardMovesProvider(widget.boardId)).isNotEmpty;
          ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = {};
          if (hadMoves) {
            for (final col in detail.columns) {
              final colCards = detail.cards.where((c) => c.columnId == col.id).toList()
                ..sort((a, b) => a.position.compareTo(b.position));
              final cardsStr = colCards.map((c) => 'id:${c.id}:pos:${c.position}').join(', ');
              debugPrint('[카드이동] 서버 데이터 수신 → 낙관적 초기화 | columnId=${col.id} cards=$cardsStr');
            }
          }
        });
      }
    });
    return widget.child;
  }

  void _applyCardCreated(Map<String, dynamic> data) {
    final cardJson = data['card'] as Map<String, dynamic>?;
    if (cardJson == null) return;

    final incoming = CardItem.fromJson(cardJson);
    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final nextCards = current.cards.where((c) => c.id != incoming.id).toList()..add(incoming);
    nextCards.sort((a, b) {
      final byColumn = a.columnId.compareTo(b.columnId);
      if (byColumn != 0) return byColumn;
      return a.position.compareTo(b.position);
    });

    ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion: (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  void _applyBoardJoined(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final membersRaw = data['members_online'] as List?;
    if (membersRaw == null) return;

    final members = membersRaw
        .whereType<Map>()
        .map((e) => PresenceMember(
              userId: (e['user_id'] as num).toInt(),
              display: (e['display'] as String?) ?? 'user',
              email: e['email'] as String?,
            ))
        .toList();
    ref.read(presenceMembersProvider(widget.boardId).notifier).state = members;
  }

  void _applyPresenceJoined(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final user = data['user'] as Map<String, dynamic>?;
    if (user == null) return;
    final userId = (user['user_id'] as num?)?.toInt();
    if (userId == null) return;
    final display = (user['display'] as String?) ?? 'user';
    final email = user['email'] as String?;

    final current = ref.read(presenceMembersProvider(widget.boardId));
    if (current.any((m) => m.userId == userId)) return;
    ref.read(presenceMembersProvider(widget.boardId).notifier).state = [
      ...current,
      PresenceMember(userId: userId, display: display, email: email),
    ];
  }

  void _applyPresenceLeft(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final userId = (data['user_id'] as num?)?.toInt();
    if (userId == null) return;
    final current = ref.read(presenceMembersProvider(widget.boardId));
    ref.read(presenceMembersProvider(widget.boardId).notifier).state = current
        .where((m) => m.userId != userId)
        .toList();
  }

  void _applyCardLocked(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final cardId = (data['card_id'] as num?)?.toInt();
    final lockedBy = data['locked_by'] as Map<String, dynamic>?;
    final expiresAt = (data['expires_at'] as num?)?.toInt();
    if (cardId == null || lockedBy == null || expiresAt == null) return;
    final userId = (lockedBy['user_id'] as num?)?.toInt();
    final display = lockedBy['display'] as String?;
    if (userId == null || display == null) return;

    final locks = Map<int, CardLockState>.from(
      ref.read(cardLocksProvider(widget.boardId)),
    );
    locks[cardId] = CardLockState(
      cardId: cardId,
      lockedByUserId: userId,
      lockedByDisplay: display,
      expiresAt: expiresAt,
    );
    ref.read(cardLocksProvider(widget.boardId).notifier).state = locks;
  }

  void _applyCardUnlocked(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final cardId = (data['card_id'] as num?)?.toInt();
    if (cardId == null) return;
    final locks = Map<int, CardLockState>.from(
      ref.read(cardLocksProvider(widget.boardId)),
    )..remove(cardId);
    ref.read(cardLocksProvider(widget.boardId).notifier).state = locks;
  }

  void _applyCardMoved(Map<String, dynamic> data) {
    final cardId = data['card_id'] as int?;
    final columnId = data['column_id'] as int?;
    final position = data['position'] as int?;
    if (cardId == null || columnId == null || position == null) return;

    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final order = (data['column_cards'] as List?)
        ?.whereType<Map>()
        .map((e) => {
              'id': e['id'] as int?,
              'position': e['position'] as int?,
            })
        .where((e) => e['id'] != null && e['position'] != null)
        .toList();

    final positionMap = <int, int>{};
    if (order != null) {
      for (final item in order) {
        positionMap[item['id']!] = item['position']!;
      }
    }

    final nextCards = current.cards.map((c) {
      if (c.id == cardId) {
        return c.copyWith(
          columnId: columnId,
          position: position,
        );
      }
      final normalized = positionMap[c.id];
      if (normalized != null && c.columnId == columnId) {
        return c.copyWith(position: normalized);
      }
      return c;
    }).toList();

    nextCards.sort((a, b) {
      final byColumn = a.columnId.compareTo(b.columnId);
      if (byColumn != 0) return byColumn;
      return a.position.compareTo(b.position);
    });

    ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion: (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  void _applyCardUpdated(Map<String, dynamic> data) {
    final cardId = data['card_id'] as int?;
    final patch = data['patch'] as Map<String, dynamic>?;
    if (cardId == null || patch == null) return;

    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final nextCards = current.cards.map((c) {
      if (c.id != cardId) return c;
      return c.copyWith(
        title: patch.containsKey('title') ? (patch['title'] as String?) : null,
        description: patch.containsKey('description') ? (patch['description'] as String?) : null,
        priority: patch.containsKey('priority') ? (patch['priority'] as String?) : null,
        columnId: patch.containsKey('column_id') ? (patch['column_id'] as int?) : null,
        position: patch.containsKey('position') ? (patch['position'] as int?) : null,
        status: patch.containsKey('status') ? (patch['status'] as String?) : null,
      );
    }).toList();

    nextCards.sort((a, b) {
      final byColumn = a.columnId.compareTo(b.columnId);
      if (byColumn != 0) return byColumn;
      return a.position.compareTo(b.position);
    });

    ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion: (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  void _applyCardArchived(Map<String, dynamic> data) {
    final cardId = data['card_id'] as int?;
    if (cardId == null) return;
    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final nextCards = current.cards.where((c) => c.id != cardId).toList();
    ref.read(boardDetailCacheProvider(widget.boardId).notifier).state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion: (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _wsService.leaveBoard(widget.boardId);
    super.dispose();
  }
}

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

  @override
  void initState() {
    super.initState();
    _columns = List<ColumnItem>.from(widget.initialColumns)
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<String?> _requireToken() async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('sessionExpired'))));
    }
    return token;
  }

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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          Switch(
                            value: col.isDone,
                            onChanged: _loading ? null : (v) => _toggleDone(col, v),
                          ),
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
class _BoardMenuButton extends ConsumerWidget {
  const _BoardMenuButton({
    required this.boardId,
    required this.currentTitle,
    required this.onTitleChanged,
  });

  final int boardId;
  final String currentTitle;
  final void Function(String) onTitleChanged;

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
class _InviteButton extends ConsumerStatefulWidget {
  const _InviteButton({required this.boardId});

  final int boardId;

  @override
  ConsumerState<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends ConsumerState<_InviteButton> {
  bool _loading = false;

  Future<void> _showInviteSheet() async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final invite = await ref.read(boardHandlerProvider).createInvite(token, widget.boardId);
      if (!mounted) return;
      _loading = false;
      setState(() {});

      showModalBottomSheet(
        context: context,
        builder: (ctx) => _InviteCodeSheet(
          code: invite.code,
          expiresAt: invite.expiresAt,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add),
      onPressed: _loading ? null : _showInviteSheet,
      tooltip: context.tr('inviteMember'),
    );
  }
}

class _InviteCodeSheet extends StatelessWidget {
  const _InviteCodeSheet({required this.code, required this.expiresAt});

  final String code;
  final String expiresAt;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('inviteMember'),
            style: TextStyle(
              fontSize: ConfigUI.fontSizeSubtitle,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('inviteShareHint'),
            style: TextStyle(fontSize: ConfigUI.fontSizeBody, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: p.cardBackground,
              borderRadius: ConfigUI.cardRadius,
              border: Border.all(color: p.divider),
            ),
            child: Center(
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: p.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('inviteCodeCopied'))),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(context.tr('copy')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CustomNavigationUtil.back(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('inviteCodeCopied'))),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(context.tr('copyAndClose')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// WebSocket 연결 상태 표시 (초록=연결됨, 회색=끊김)
class _WsConnectionIndicator extends ConsumerWidget {
  const _WsConnectionIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wsConnectionStateProvider);
    return state.when(
      loading: () => _dot(context, false),
      error: (_, __) => _dot(context, false),
      data: (connected) => Tooltip(
        message: connected ? context.tr('syncConnected') : context.tr('syncDisconnected'),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _dot(context, connected),
        ),
      ),
    );
  }

  Widget _dot(BuildContext context, bool connected) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? Colors.green : Colors.grey,
        boxShadow: [
          BoxShadow(
            color: (connected ? Colors.green : Colors.grey).withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _PresenceAvatarsButton extends ConsumerWidget {
  const _PresenceAvatarsButton({required this.boardId});

  final int boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(presenceMembersProvider(boardId));
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: context.tr('presenceCount', namedArgs: {'count': '${members.length}'}),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => _PresenceMembersSheet(members: members),
        );
      },
      icon: SizedBox(
        width: 64,
        height: 24,
        child: Stack(
          children: [
            for (var i = 0; i < members.length && i < 3; i++)
              Positioned(
                left: i * 16,
                child: _AvatarDot(label: members[i].display),
              ),
            if (members.length > 3)
              Positioned(
                left: 48,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '+${members.length - 3}',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final colors = [
      const Color(0xFFEF5350),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFFFA726),
      const Color(0xFFAB47BC),
      const Color(0xFF26A69A),
    ];
    final color = colors[trimmed.hashCode.abs() % colors.length];
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PresenceMembersSheet extends StatelessWidget {
  const _PresenceMembersSheet({required this.members});
  final List<PresenceMember> members;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('presenceConnecting', namedArgs: {'count': '${members.length}'}),
            style: TextStyle(
              fontSize: ConfigUI.fontSizeSubtitle,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _AvatarDot(label: m.display),
                    const SizedBox(width: 10),
                    Text(
                      (m.email != null && m.email!.trim().isNotEmpty)
                          ? m.email!
                          : m.display,
                      style: TextStyle(color: p.textPrimary),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ColumnView extends ConsumerStatefulWidget {
  const _ColumnView({
    super.key,
    required this.column,
    required this.cards,
    required this.columns,
    required this.boardId,
    required this.onRefresh,
  });

  final ColumnItem column;
  final List<CardItem> cards;
  final List<ColumnItem> columns;
  final int boardId;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends ConsumerState<_ColumnView> {
  late List<CardItem> _displayCards;
  static const Duration _moveAckTimeout = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _displayCards = List.from(widget.cards);
  }

  @override
  void didUpdateWidget(_ColumnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(widget.cards, oldWidget.cards)) {
      _displayCards = List.from(widget.cards);
    }
  }

  bool _listEquals(List<CardItem> a, List<CardItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position != b[i].position ||
          a[i].columnId != b[i].columnId ||
          a[i].title != b[i].title ||
          a[i].description != b[i].description ||
          a[i].priority != b[i].priority ||
          a[i].status != b[i].status) {
        return false;
      }
    }
    return true;
  }

  void _showAddCardDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddCardSheet(
        columnId: widget.column.id,
        boardId: widget.boardId,
        onSaved: () => CustomNavigationUtil.back(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: 0.15),
            borderRadius: ConfigUI.cardRadius,
            border: Border.all(color: p.borderBrutal, width: ConfigUI.borderWidthBrutal),
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
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddCardDialog,
                tooltip: context.tr('cardAdd'),
              ),
            ],
          ),
        ),
        const SizedBox(height: ConfigUI.gapColumnHeaderToCards),
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.only(
              left: ConfigUI.screenPaddingH,
              right: ConfigUI.screenPaddingH,
              top: 0,
              bottom: ConfigUI.gapBetweenCards,
            ),
            itemCount: _displayCards.length + 1,
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex),
            proxyDecorator: (child, index, animation) {
              final scale = Tween<double>(begin: 1, end: 1.04).animate(animation);
              return AnimatedBuilder(
                animation: animation,
                builder: (_, __) => Transform.scale(
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
                padding: const EdgeInsets.only(bottom: ConfigUI.gapBetweenCards),
                child: CardTile(
                  card: card,
                  onTap: () => _showCardDetail(card),
                  onRefresh: widget.onRefresh,
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final session = ref.read(sessionNotifierProvider).value;
    final userId = session?.userId ?? -1;

    if (oldIndex >= _displayCards.length) {
      debugPrint('[카드이동] 사용자:$userId - 원인덱스:$oldIndex - 이동인덱스:$newIndex → 스킵(범위초과, cards=${_displayCards.length})');
      return;
    }
    if (newIndex > _displayCards.length) {
      newIndex = _displayCards.length;
    }
    if (oldIndex == newIndex) {
      debugPrint('[카드이동] 사용자:$userId - 원인덱스:$oldIndex - 이동인덱스:$newIndex → 스킵(동일위치)');
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

    debugPrint('[카드이동] 사용자:$userId - 원인덱스:$oldIndex - 이동인덱스:$newIndex | cardId=${movedCard.id} columnId=${widget.column.id} position=$newPosition');

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
    ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = optimistic;

    final ws = ref.read(wsServiceProvider);
    if (ws.isConnected) {
      debugPrint('[카드이동] 사용자:$userId - WebSocket CARD_MOVE 전송');
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
        debugPrint('[카드이동] 사용자:$userId - WebSocket 실패: $e\n$st');
        if (mounted) {
          final pending = Set<String>.from(
            ref.read(pendingMoveReqIdsProvider(widget.boardId)),
          )..remove(reqId);
          ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state = pending;
          final retryMap = Map<String, int>.from(
            ref.read(pendingMoveRetryCountProvider(widget.boardId)),
          )..remove(reqId);
          ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = retryMap;
          final rollback = Map<int, OptimisticCardMove>.from(
            ref.read(optimisticCardMovesProvider(widget.boardId)),
          );
          rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
          ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = rollback;
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('cardMoveFailed'))),
          );
        }
      }
      return;
    }

    // WebSocket 미연결 시 REST API 폴백
    final token = session?.sessionToken;
    if (token == null) {
      debugPrint('[카드이동] 사용자:$userId - REST 스킵(토큰없음)');
      final rollback = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = rollback;
      widget.onRefresh();
      return;
    }
    debugPrint('[카드이동] 사용자:$userId - REST API updateCard 호출');
    try {
      await ref.read(cardHandlerProvider).updateCard(
        token,
        movedCard.id,
        columnId: widget.column.id,
        position: newPosition,
      );
      final committed = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      committed.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = committed;
      debugPrint('[카드이동] 사용자:$userId - REST 성공');
      widget.onRefresh();
    } on ApiException catch (e) {
      debugPrint('[카드이동] 사용자:$userId - REST 실패: ${e.message}');
      if (mounted) {
        final rollback = Map<int, OptimisticCardMove>.from(
          ref.read(optimisticCardMovesProvider(widget.boardId)),
        );
        rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
        ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = rollback;
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

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

  (int?, int?) _computeNeighborIds(List<CardItem> reorderedCards, int newIndex) {
    final beforeId = newIndex > 0 ? reorderedCards[newIndex - 1].id : null;
    final afterId = newIndex < reorderedCards.length - 1
        ? reorderedCards[newIndex + 1].id
        : null;
    return (beforeId, afterId);
  }

  String _newMoveReqId(int cardId) =>
      'move_${widget.boardId}_${cardId}_${DateTime.now().microsecondsSinceEpoch}';

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
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = retryMap;
        try {
          debugPrint('[카드이동] ACK 타임아웃 → 재전송(req_id=$reqId)');
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
      ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state = nextPending;

      retryMap.remove(reqId);
      ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state = retryMap;

      final rollback = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      rollback.removeWhere((cardId, _) => affectedCardIds.contains(cardId));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state = rollback;

      ref.invalidate(boardDetailProvider(widget.boardId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('syncRefresh'))),
        );
      }
    });
  }
}

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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

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
          description: _descController.text.trim().isEmpty ? '' : _descController.text.trim(),
          reqId: reqId,
        );
        widget.onSaved();
        return;
      }

      await ref.read(cardHandlerProvider).createCard(
        token,
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        columnId: widget.columnId,
      );
      ref.invalidate(boardDetailProvider(widget.boardId));
      widget.onSaved();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
              maxLines: 3,
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
