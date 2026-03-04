part of 'package:syncflow/view/board_detail_screen.dart';
// WebSocket 수신/동기화 브리지
//
// [구조 하이라키]
// _BoardWsBridge
// └─ _BoardWsBridgeState
//    ├─ WS 연결/재조인 관리
//    ├─ 이벤트 디스패치(_onWsMessage)
//    └─ 캐시/낙관적 상태 반영(_apply*)

/// 보드 상세 화면의 WS 생명주기를 감싸는 브리지 위젯.
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

  /// 진입 시 보드 룸에 JOIN하고, 메시지/연결 상태 스트림을 구독한다.
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

  /// 서버 이벤트를 타입별로 분기해 캐시/상태를 반영한다.
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
    if (type == 'BOARD_UPDATED' && data != null) {
      final bid = (data['board_id'] as num?)?.toInt();
      final title = data['title'] as String?;
      if (bid == widget.boardId && title != null && title.isNotEmpty) {
        ref.read(boardTitleOverrideProvider(widget.boardId).notifier).state =
            title;
        ref.invalidate(boardDetailProvider(widget.boardId));
        ref.read(boardListNotifierProvider.notifier).refresh();
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
        ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state =
            pendingReqIds;

        final retryMap = Map<String, int>.from(
          ref.read(pendingMoveRetryCountProvider(widget.boardId)),
        )..remove(reqId);
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state =
            retryMap;
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
      final isLockReleaseFail = code == 'LOCKED' && message.contains('락 해제 실패');
      if (isLockReleaseFail) {
        debugPrint('[LOCK] $message');
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    if (data == null) return;
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final incomingVersion = (data['board_version'] as num?)?.toInt();
    final currentVersion = ref.read(boardVersionProvider(widget.boardId));
    final isCardMoved = type == 'CARD_MOVED';

    if (isCardMoved) {
      final columnId = (data['column_id'] as num?)?.toInt();
      final incomingMovedAt =
          (data['updated_at'] as num?)?.toInt() ?? incomingVersion;
      if (columnId != null && incomingMovedAt != null) {
        final lastByColumn = ref.read(
          lastAppliedMoveEventAtProvider(widget.boardId),
        );
        final lastMovedAt = lastByColumn[columnId];
        if (lastMovedAt != null && incomingMovedAt < lastMovedAt) {
          return;
        }
      }
    }

    if (!isCardMoved &&
        incomingVersion != null &&
        currentVersion != null &&
        incomingVersion < currentVersion) {
      return;
    }
    if (incomingVersion != null &&
        (currentVersion == null || incomingVersion > currentVersion)) {
      ref.read(boardVersionProvider(widget.boardId).notifier).state =
          incomingVersion;
    }

    const cardTypes = [
      'CARD_CREATED',
      'CARD_MOVED',
      'CARD_UPDATED',
      'CARD_ARCHIVED',
      'CARD_RESTORED',
    ];
    if (cardTypes.contains(type)) {
      final reqId = msg['req_id'] as String?;
      final pendingReqIds = ref.read(pendingMoveReqIdsProvider(widget.boardId));
      final isAckForMyMove =
          type == 'CARD_MOVED' &&
          reqId != null &&
          pendingReqIds.contains(reqId);

      if (isAckForMyMove) {
        final nextPending = Set<String>.from(pendingReqIds)..remove(reqId);
        ref.read(pendingMoveReqIdsProvider(widget.boardId).notifier).state =
            nextPending;
        final retryMap = Map<String, int>.from(
          ref.read(pendingMoveRetryCountProvider(widget.boardId)),
        )..remove(reqId);
        ref.read(pendingMoveRetryCountProvider(widget.boardId).notifier).state =
            retryMap;
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

  /// provider 갱신 완료 후 캐시/버전을 프레임 끝에서 안전하게 반영한다.
  @override
  Widget build(BuildContext context) {
    ref.listen(boardDetailProvider(widget.boardId), (prev, next) {
      if (!next.isLoading && next.value != null) {
        final detail = next.value!;
        // build 단계 중 provider state 변경을 피하기 위해 프레임 이후 반영
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final pendingReqIds = ref.read(
            pendingMoveReqIdsProvider(widget.boardId),
          );
          if (pendingReqIds.isNotEmpty) {
            // 아직 ACK 대기 중인 이동이 있으면 낙관적 상태 유지
            return;
          }
          // CARD_MOVED로 이미 더 최신 상태면 덮어쓰지 않음 (refetch 레이스 방지)
          final current = ref.read(boardDetailCacheProvider(widget.boardId));
          final newVersion = detail.boardVersion ?? 0;
          final currentVersion = current?.boardVersion ?? 0;
          if (current != null && newVersion < currentVersion) {
            return;
          }
          ref.read(boardDetailCacheProvider(widget.boardId).notifier).state =
              detail;
          ref.read(boardVersionProvider(widget.boardId).notifier).state =
              detail.boardVersion;
          ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
              {};
        });
      }
    });
    return widget.child;
  }

  /// CARD_CREATED 이벤트를 캐시에 병합한다.
  void _applyCardCreated(Map<String, dynamic> data) {
    final cardJson = data['card'] as Map<String, dynamic>?;
    if (cardJson == null) return;

    final incoming = CardItem.fromJson(cardJson);
    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final nextCards = current.cards.where((c) => c.id != incoming.id).toList()
      ..add(incoming);
    nextCards.sort((a, b) {
      final byColumn = a.columnId.compareTo(b.columnId);
      if (byColumn != 0) return byColumn;
      return a.position.compareTo(b.position);
    });

    ref
        .read(boardDetailCacheProvider(widget.boardId).notifier)
        .state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion:
          (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  /// BOARD_JOINED 이벤트의 접속자 목록을 초기화한다.
  void _applyBoardJoined(Map<String, dynamic> data) {
    final bid = data['board_id'];
    if (bid != widget.boardId) return;
    final membersRaw = data['members_online'] as List?;
    if (membersRaw == null) return;

    final members = membersRaw
        .whereType<Map>()
        .map(
          (e) => PresenceMember(
            userId: (e['user_id'] as num).toInt(),
            display: (e['display'] as String?) ?? 'user',
            email: e['email'] as String?,
          ),
        )
        .toList();
    ref.read(presenceMembersProvider(widget.boardId).notifier).state = members;
  }

  /// PRESENCE_JOINED 이벤트를 접속자 목록에 추가한다.
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

  /// PRESENCE_LEFT 이벤트를 접속자 목록에서 제거한다.
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

  /// CARD_LOCKED 이벤트로 카드 잠금 상태를 반영한다.
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

  /// CARD_UNLOCKED 이벤트로 카드 잠금 상태를 해제한다.
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

  /// CARD_MOVED 이벤트를 적용하고 정렬/낙관적 상태를 정리한다.
  void _applyCardMoved(Map<String, dynamic> data) {
    final cardId = (data['card_id'] as num?)?.toInt();
    final columnId = (data['column_id'] as num?)?.toInt();
    final position = (data['position'] as num?)?.toInt();
    if (cardId == null || columnId == null || position == null) return;

    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final order = (data['column_cards'] as List?)
        ?.whereType<Map>()
        .map(
          (e) => {
            'id': (e['id'] as num?)?.toInt(),
            'position': (e['position'] as num?)?.toInt(),
          },
        )
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
        return c.copyWith(columnId: columnId, position: position);
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

    ref
        .read(boardDetailCacheProvider(widget.boardId).notifier)
        .state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion:
          (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );

    final movedAt =
        (data['updated_at'] as num?)?.toInt() ??
        (data['board_version'] as num?)?.toInt();
    if (movedAt != null) {
      final byColumn = Map<int, int>.from(
        ref.read(lastAppliedMoveEventAtProvider(widget.boardId)),
      );
      final currentMovedAt = byColumn[columnId];
      if (currentMovedAt == null || movedAt >= currentMovedAt) {
        byColumn[columnId] = movedAt;
        ref
                .read(lastAppliedMoveEventAtProvider(widget.boardId).notifier)
                .state =
            byColumn;
      }
    }

    final confirmedIds = <int>{cardId, ...positionMap.keys};
    if (confirmedIds.isNotEmpty) {
      final optimistic = Map<int, OptimisticCardMove>.from(
        ref.read(optimisticCardMovesProvider(widget.boardId)),
      );
      optimistic.removeWhere((id, _) => confirmedIds.contains(id));
      ref.read(optimisticCardMovesProvider(widget.boardId).notifier).state =
          optimistic;
    }
  }

  /// CARD_UPDATED 패치를 카드 캐시에 반영한다.
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
        description: patch.containsKey('description')
            ? (patch['description'] as String?)
            : null,
        priority: patch.containsKey('priority')
            ? (patch['priority'] as String?)
            : null,
        columnId: patch.containsKey('column_id')
            ? (patch['column_id'] as int?)
            : null,
        position: patch.containsKey('position')
            ? (patch['position'] as int?)
            : null,
        status: patch.containsKey('status')
            ? (patch['status'] as String?)
            : null,
        assigneeId: patch.containsKey('assignee_id')
            ? (patch['assignee_id'] as num?)?.toInt()
            : null,
        clearAssigneeId:
            patch.containsKey('assignee_id') && patch['assignee_id'] == null,
        mentionedUserIds: patch.containsKey('mentioned_user_ids')
            ? (patch['mentioned_user_ids'] as List?)
                      ?.map((e) => (e as num).toInt())
                      .toList() ??
                  const []
            : null,
      );
    }).toList();

    nextCards.sort((a, b) {
      final byColumn = a.columnId.compareTo(b.columnId);
      if (byColumn != 0) return byColumn;
      return a.position.compareTo(b.position);
    });

    ref
        .read(boardDetailCacheProvider(widget.boardId).notifier)
        .state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion:
          (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  /// CARD_ARCHIVED 이벤트로 카드를 캐시에서 제거한다.
  void _applyCardArchived(Map<String, dynamic> data) {
    final cardId = data['card_id'] as int?;
    if (cardId == null) return;
    final current = ref.read(boardDetailCacheProvider(widget.boardId));
    if (current == null) {
      ref.invalidate(boardDetailProvider(widget.boardId));
      return;
    }

    final nextCards = current.cards.where((c) => c.id != cardId).toList();
    ref
        .read(boardDetailCacheProvider(widget.boardId).notifier)
        .state = BoardDetail(
      id: current.id,
      title: current.title,
      ownerId: current.ownerId,
      columns: current.columns,
      cards: nextCards,
      boardVersion:
          (data['board_version'] as num?)?.toInt() ?? current.boardVersion,
    );
  }

  /// 화면 이탈 시 스트림 구독을 해제하고 보드 룸을 LEAVE한다.
  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _wsService.leaveBoard(widget.boardId);
    super.dispose();
  }
}
