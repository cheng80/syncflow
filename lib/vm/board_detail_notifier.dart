// board_detail_notifier.dart
// 보드 상세 상태 관리 (컬럼+카드)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:syncflow/model/board.dart';
import 'package:syncflow/vm/board_handler.dart';
import 'package:syncflow/vm/session_notifier.dart';

/// 카드 이동 낙관적 업데이트용 (cardId -> columnId, position)
class OptimisticCardMove {
  const OptimisticCardMove({required this.columnId, required this.position});
  final int columnId;
  final int position;
}

/// 보드별 낙관적 카드 이동 상태 (드래그 시 즉시 반영, 서버 동기화 후 제거)
final optimisticCardMovesProvider =
    StateProvider.family<Map<int, OptimisticCardMove>, int>((ref, boardId) => {});

/// 보드별 대기 중인 CARD_MOVE req_id 집합
final pendingMoveReqIdsProvider =
    StateProvider.family<Set<String>, int>((ref, boardId) => <String>{});

/// 보드별 이동 요청 재시도 카운트(req_id -> retryCount)
final pendingMoveRetryCountProvider =
    StateProvider.family<Map<String, int>, int>((ref, boardId) => <String, int>{});

/// 보드 상세 캐시 (WS 부분 패치 반영용)
final boardDetailCacheProvider =
    StateProvider.family<BoardDetail?, int>((ref, boardId) => null);

/// 마지막으로 적용한 보드 버전(ms epoch)
final boardVersionProvider =
    StateProvider.family<int?, int>((ref, boardId) => null);

/// 서버 데이터 + 낙관적 이동을 합친 카드 목록
List<CardItem> mergeCardsWithOptimistic(
  List<CardItem> cards,
  Map<int, OptimisticCardMove> moves,
) {
  if (moves.isEmpty) return cards;
  return cards.map((c) {
    final m = moves[c.id];
    return m != null ? c.copyWith(columnId: m.columnId, position: m.position) : c;
  }).toList();
}

/// 보드 ID별 상세 Provider (갱신 시 ref.invalidate(boardDetailProvider(boardId)))
final boardDetailProvider =
    FutureProvider.family<BoardDetail?, int>((ref, boardId) async {
  final session = ref.watch(sessionNotifierProvider).value;
  final token = session?.sessionToken;
  if (token == null) return null;

  try {
    return await ref.read(boardHandlerProvider).getBoardDetail(token, boardId);
  } catch (_) {
    return null;
  }
});
