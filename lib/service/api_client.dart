// api_client.dart
// SyncFlow REST API 클라이언트

import 'package:http/http.dart' as http;

import 'package:syncflow/json/custom_json_util.dart';
import 'package:syncflow/model/board.dart';
import 'package:syncflow/util/common_util.dart';

/// API 클라이언트
/// baseUrl 미지정 시 getApiBaseUrl() 사용 (Android: 10.0.2.2, iOS: 127.0.0.1)
class ApiClient {
  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? getApiBaseUrl();

  final String _baseUrl;

  String _url(String path) => '$_baseUrl$path';

  /// POST /v1/auth/send-code
  /// 이메일로 인증 코드 발송
  Future<SendCodeResponse> sendAuthCode(String email) async {
    final res = await http.post(
      Uri.parse(_url('/v1/auth/send-code')),
      headers: {'Content-Type': 'application/json'},
      body: CustomJsonUtil.encode({'email': email}) ?? '',
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '인증 코드 발송 실패');
    }
    return SendCodeResponse.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// POST /v1/auth/verify
  /// 인증 코드 검증 → 세션 토큰 반환
  Future<VerifyResponse> verifyAuthCode(String email, String code) async {
    final res = await http.post(
      Uri.parse(_url('/v1/auth/verify')),
      headers: {'Content-Type': 'application/json'},
      body: CustomJsonUtil.encode({'email': email, 'code': code}) ?? '',
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '인증 실패');
    }
    return VerifyResponse.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'X-Session-Token': token,
      };

  /// GET /v1/auth/me - 현재 사용자 ID 조회
  Future<int> getMe(String sessionToken) async {
    final res = await http.get(
      Uri.parse(_url('/v1/auth/me')),
      headers: _authHeaders(sessionToken),
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '사용자 조회 실패');
    }
    final j = CustomJsonUtil.decode(res.body) as Map<String, dynamic>?;
    return j?['user_id'] as int;
  }

  /// GET /v1/boards - 보드 목록
  Future<List<BoardItem>> listBoards(String sessionToken) async {
    final res = await http.get(
      Uri.parse(_url('/v1/boards')),
      headers: _authHeaders(sessionToken),
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '보드 목록 조회 실패');
    }
    final list = CustomJsonUtil.fromJsonList<BoardItem>(
      res.body,
      (j) => BoardItem.fromJson(j),
    );
    return list ?? [];
  }

  /// POST /v1/boards - 보드 생성
  Future<BoardItem> createBoard(String sessionToken, String title, {String template = 'todo'}) async {
    final res = await http.post(
      Uri.parse(_url('/v1/boards')),
      headers: _authHeaders(sessionToken),
      body: CustomJsonUtil.encode({'title': title, 'template': template}) ?? '',
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '보드 생성 실패');
    }
    return BoardItem.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// POST /v1/boards/{id}/invite - 초대 코드 생성 (owner만)
  Future<InviteResponse> createInvite(String sessionToken, int boardId) async {
    final res = await http.post(
      Uri.parse(_url('/v1/boards/$boardId/invite')),
      headers: _authHeaders(sessionToken),
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '초대 코드 생성 실패');
    }
    return InviteResponse.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// POST /v1/boards/join - 초대 코드로 보드 참가
  Future<JoinBoardResponse> joinBoardByCode(String sessionToken, String code) async {
    final res = await http.post(
      Uri.parse(_url('/v1/boards/join')),
      headers: _authHeaders(sessionToken),
      body: CustomJsonUtil.encode({'code': code}) ?? '',
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '보드 참가 실패');
    }
    return JoinBoardResponse.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// GET /v1/boards/{id} - 보드 상세
  Future<BoardDetail> getBoardDetail(String sessionToken, int boardId) async {
    final res = await http.get(
      Uri.parse(_url('/v1/boards/$boardId')),
      headers: _authHeaders(sessionToken),
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '보드 조회 실패');
    }
    return BoardDetail.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// POST /v1/cards - 카드 생성
  Future<CardItem> createCard(
    String sessionToken, {
    required String title,
    String? description,
    required int columnId,
    String priority = 'medium',
  }) async {
    final res = await http.post(
      Uri.parse(_url('/v1/cards')),
      headers: _authHeaders(sessionToken),
      body: CustomJsonUtil.encode({
        'title': title,
        'description': description ?? '',
        'column_id': columnId,
        'priority': priority,
      }) ?? '',
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '카드 생성 실패');
    }
    return CardItem.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// PATCH /v1/cards/{id} - 카드 수정
  Future<CardItem> updateCard(
    String sessionToken,
    int cardId, {
    String? title,
    String? description,
    int? columnId,
    String? priority,
    int? position,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (columnId != null) body['column_id'] = columnId;
    if (priority != null) body['priority'] = priority;
    if (position != null) body['position'] = position;
    if (body.isEmpty) throw ApiException('수정할 항목이 없습니다.');

    final res = await http.patch(
      Uri.parse(_url('/v1/cards/$cardId')),
      headers: _authHeaders(sessionToken),
      body: CustomJsonUtil.encode(body) ?? '',
    );
    if (res.statusCode != 200) {
      final err = CustomJsonUtil.toMap(res.body);
      throw ApiException(err?['detail'] ?? '카드 수정 실패');
    }
    return CardItem.fromJson(
      CustomJsonUtil.decode(res.body) as Map<String, dynamic>,
    );
  }

  /// DELETE /v1/cards/{id} - 카드 아카이브
  Future<void> archiveCard(String sessionToken, int cardId) async {
    final res = await http.delete(
      Uri.parse(_url('/v1/cards/$cardId')),
      headers: _authHeaders(sessionToken),
    );
    if (res.statusCode != 200) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '카드 삭제 실패');
    }
  }

  /// POST /v1/auth/logout
  Future<void> logout(String sessionToken) async {
    final res = await http.post(
      Uri.parse(_url('/v1/auth/logout')),
      headers: {'Content-Type': 'application/json'},
      body: CustomJsonUtil.encode({'session_token': sessionToken}) ?? '',
    );
    if (res.statusCode != 200 && res.statusCode != 404) {
      final body = CustomJsonUtil.toMap(res.body);
      throw ApiException(body?['detail'] ?? '로그아웃 실패');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SendCodeResponse {
  SendCodeResponse({required this.ok, this.message});
  factory SendCodeResponse.fromJson(Map<String, dynamic> j) =>
      SendCodeResponse(ok: j['ok'] ?? false, message: j['message'] as String?);
  final bool ok;
  final String? message;
}

class VerifyResponse {
  VerifyResponse({
    required this.sessionToken,
    required this.expiresAt,
    required this.userId,
  });
  factory VerifyResponse.fromJson(Map<String, dynamic> j) => VerifyResponse(
        sessionToken: j['session_token'] as String,
        expiresAt: j['expires_at'] as String,
        userId: j['user_id'] as int,
      );
  final String sessionToken;
  final String expiresAt;
  final int userId;
}

class InviteResponse {
  InviteResponse({required this.code, required this.expiresAt});
  factory InviteResponse.fromJson(Map<String, dynamic> j) =>
      InviteResponse(code: j['code'] as String, expiresAt: j['expires_at'] as String);
  final String code;
  final String expiresAt;
}

class JoinBoardResponse {
  JoinBoardResponse({required this.boardId, required this.title, this.message});
  factory JoinBoardResponse.fromJson(Map<String, dynamic> j) => JoinBoardResponse(
        boardId: j['board_id'] as int,
        title: j['title'] as String,
        message: j['message'] as String?,
      );
  final int boardId;
  final String title;
  final String? message;
}
