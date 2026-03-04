// board_handler.dart
// 보드 API 접근 전담 (CURSOR.md Handler 규칙)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/service/api_client.dart';

final boardHandlerProvider = Provider<BoardHandler>((ref) => BoardHandler());

/// 보드 API Handler - DB/API 접근 전담
class BoardHandler {
  BoardHandler({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<BoardItem>> listBoards(String sessionToken) =>
      _client.listBoards(sessionToken);

  Future<BoardItem> createBoard(String sessionToken, String title, {String template = 'todo'}) =>
      _client.createBoard(sessionToken, title, template: template);

  Future<BoardDetail> getBoardDetail(String sessionToken, int boardId) =>
      _client.getBoardDetail(sessionToken, boardId);

  Future<List<BoardMemberItem>> listBoardMembers(String sessionToken, int boardId) =>
      _client.listBoardMembers(sessionToken, boardId);

  Future<BoardItem> updateBoard(String sessionToken, int boardId, {required String title}) =>
      _client.updateBoard(sessionToken, boardId, title: title);

  Future<void> deleteBoard(String sessionToken, int boardId) =>
      _client.deleteBoard(sessionToken, boardId);

  Future<ColumnItem> createColumn(
    String sessionToken,
    int boardId, {
    required String title,
    bool isDone = false,
  }) =>
      _client.createColumn(sessionToken, boardId, title: title, isDone: isDone);

  Future<ColumnItem> updateColumn(
    String sessionToken,
    int boardId,
    int columnId, {
    String? title,
    bool? isDone,
    int? position,
  }) =>
      _client.updateColumn(
        sessionToken,
        boardId,
        columnId,
        title: title,
        isDone: isDone,
        position: position,
      );

  Future<void> deleteColumn(String sessionToken, int boardId, int columnId) =>
      _client.deleteColumn(sessionToken, boardId, columnId);

  Future<InviteResponse> createInvite(String sessionToken, int boardId) =>
      _client.createInvite(sessionToken, boardId);

  Future<JoinBoardResponse> joinBoardByCode(String sessionToken, String code) =>
      _client.joinBoardByCode(sessionToken, code);
}
