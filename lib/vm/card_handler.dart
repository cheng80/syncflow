// card_handler.dart
// 카드 API 접근 전담 (CURSOR.md Handler 규칙)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/service/api_client.dart';

final cardHandlerProvider = Provider<CardHandler>((ref) => CardHandler());

/// 카드 API Handler - DB/API 접근 전담
class CardHandler {
  CardHandler({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CardItem> createCard(
    String sessionToken, {
    required String title,
    String? description,
    required int columnId,
    String priority = 'medium',
  }) => _client.createCard(
    sessionToken,
    title: title,
    description: description,
    columnId: columnId,
    priority: priority,
  );

  Future<CardItem> updateCard(
    String sessionToken,
    int cardId, {
    String? title,
    String? description,
    int? columnId,
    String? priority,
    String? status,
    int? position,
  }) => _client.updateCard(
    sessionToken,
    cardId,
    title: title,
    description: description,
    columnId: columnId,
    priority: priority,
    status: status,
    position: position,
  );

  Future<void> archiveCard(String sessionToken, int cardId) =>
      _client.archiveCard(sessionToken, cardId);
}
