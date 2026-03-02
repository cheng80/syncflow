// ws_service_notifier.dart
// WebSocket 연결/보드 룸 관리

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/service/ws_service.dart';
import 'package:syncflow/vm/session_notifier.dart';

final wsServiceProvider = Provider<WsService>((ref) {
  final ws = WsService();
  ref.onDispose(() => ws.dispose());
  return ws;
});

/// WebSocket 연결 상태 (true=연결됨, false=끊김)
/// StreamProvider: 첫 메시지 수신 시 true, 끊김 시 false
final wsConnectionStateProvider = StreamProvider<bool>((ref) {
  final ws = ref.watch(wsServiceProvider);
  return ws.connectionState;
});

/// 보드 진입 시 JOIN_BOARD, 이탈 시 LEAVE_BOARD
/// BoardDetailScreen에서 사용
/// WebSocket 실패 시 앱은 REST만으로 동작 (실시간 동기화 미지원)
Future<void> joinBoardRoom(WidgetRef ref, int boardId) async {
  final session = ref.read(sessionNotifierProvider).value;
  final token = session?.sessionToken;
  if (token == null) return;

  try {
    final ws = ref.read(wsServiceProvider);
    await ws.connect(token);
    await ws.joinBoard(boardId);
  } catch (_) {
    // WebSocket 미지원 서버(프록시 등)에서는 REST만 사용
  }
}

Future<void> leaveBoardRoom(WidgetRef ref, int boardId) async {
  final ws = ref.read(wsServiceProvider);
  await ws.leaveBoard(boardId);
}
