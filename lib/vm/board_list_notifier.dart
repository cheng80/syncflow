// board_list_notifier.dart
// 보드 목록 상태 관리

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/vm/board_handler.dart';
import 'package:syncflow/vm/card_handler.dart';
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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[BoardList] listBoards 실패: $e');
        debugPrint('$st');
      }
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

  /// 보드 수정 후 목록 갱신
  Future<BoardItem?> updateBoard(int boardId, String title) async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return null;

    try {
      final board = await ref.read(boardHandlerProvider).updateBoard(token, boardId, title: title);
      await refresh();
      return board;
    } catch (_) {
      rethrow;
    }
  }

  /// 보드 삭제 후 목록 갱신
  Future<void> deleteBoard(int boardId) async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return;

    await ref.read(boardHandlerProvider).deleteBoard(token, boardId);
    await refresh();
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

  /// 튜토리얼 보드 찾기 또는 생성 후 샘플 카드 추가
  /// [cardsPerColumn] 컬럼당 카드 수 (최초 설치: 1, 더미 데이터: 3)
  static const String tutorialBoardTitle = '튜토리얼 보드';

  Future<BoardItem?> ensureTutorialBoardWithSamples({
    required int cardsPerColumn,
  }) async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return null;

    final boardHandler = ref.read(boardHandlerProvider);
    final cardHandler = ref.read(cardHandlerProvider);

    final boards = await boardHandler.listBoards(token);
    BoardItem? board = boards.where((b) => b.title == tutorialBoardTitle).firstOrNull;
    if (board == null) {
      board = await createBoard(tutorialBoardTitle, template: 'todo');
    }
    if (board == null) return null;

    final detail = await boardHandler.getBoardDetail(token, board.id);
    final columns = detail.columns..sort((a, b) => a.position.compareTo(b.position));

    // 이미 카드가 있으면 스킵 (재시도 시 중복 방지)
    if (detail.cards.isNotEmpty) return board;

    const sampleTitles = [
      ['할 일 샘플'],
      ['진행 중 샘플'],
      ['완료 샘플'],
    ];
    const dummyTitles = [
      ['API 문서 작성', 'UI 디자인 리뷰', '테스트 케이스 작성'],
      ['백엔드 개발', '프론트엔드 통합', '디버깅'],
      ['환경 설정', 'DB 마이그레이션', '배포 준비'],
    ];
    final titlesPerColumn = cardsPerColumn == 1 ? sampleTitles : dummyTitles;

    for (var i = 0; i < columns.length && i < titlesPerColumn.length; i++) {
      final titles = titlesPerColumn[i];
      final count = cardsPerColumn == 1 ? 1 : titles.length;
      for (var j = 0; j < count; j++) {
        await cardHandler.createCard(
          token,
          title: titles[j],
          columnId: columns[i].id,
        );
      }
    }

    return board;
  }
}

final boardListNotifierProvider =
    AsyncNotifierProvider<BoardListNotifier, List<BoardItem>>(BoardListNotifier.new);
