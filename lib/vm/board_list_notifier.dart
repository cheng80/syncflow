// board_list_notifier.dart
// 보드 목록 상태 관리

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/vm/board_handler.dart';
import 'package:syncflow/vm/session_notifier.dart';

/// 보드 목록 Notifier
class BoardListNotifier extends AsyncNotifier<List<BoardItem>> {
  @override
  Future<List<BoardItem>> build() async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return [];

    try {
      return await ref.read(boardHandlerProvider).listBoards(token);
    } catch (_) {
      return [];
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  /// 초대 코드로 보드 참가 후 목록 갱신
  Future<JoinBoardResponse?> joinBoard(String code) async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return null;

    try {
      final res = await ref.read(boardHandlerProvider).joinBoardByCode(token, code.trim().toUpperCase());
      await refresh();
      return res;
    } catch (_) {
      rethrow;
    }
  }

  /// 보드 생성 후 목록 갱신
  /// template: "todo" (할 일/진행 중/완료), "simple" (단일 컬럼)
  Future<BoardItem?> createBoard(String title, {String template = 'todo'}) async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return null;

    try {
      final board = await ref.read(boardHandlerProvider).createBoard(token, title, template: template);
      await refresh();
      return board;
    } catch (_) {
      rethrow;
    }
  }
}

final boardListNotifierProvider =
    AsyncNotifierProvider<BoardListNotifier, List<BoardItem>>(BoardListNotifier.new);
