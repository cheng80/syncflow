// ws_service.dart
// WebSocket 연결/재연결, JOIN_BOARD

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:syncflow/json/custom_json_util.dart';
import 'package:syncflow/util/common_util.dart';

/// WebSocket 서비스 - 연결/재연결, 보드 룸 참가
class WsService {
  WsService();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _sessionToken;
  bool _closed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelayMs = 30000;
  static const int _initialReconnectDelayMs = 1000;

  /// 메시지 수신 스트림 (외부에서 listen)
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// 연결 상태 스트림 (true=연결됨, false=끊김)
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// 연결 상태 (마지막 값)
  bool get isConnected => _channel != null;

  /// sessionToken으로 연결
  /// 기존 연결이 있으면 먼저 닫음
  Future<void> connect(String sessionToken) async {
    _closed = false;
    _sessionToken = sessionToken;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_sessionToken == null || _sessionToken!.isEmpty) return;
    if (_closed) return;

    final baseUrl = getApiBaseUrl();
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final wsHost = baseUrl
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    final token = _sessionToken!.trim();
    final uri = Uri.parse('$wsScheme://$wsHost/ws?token=${Uri.encodeComponent(token)}');

    try {
      _channel = WebSocketChannel.connect(uri);
      _reconnectAttempts = 0;

      _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        _onData,
        onError: (e) {
          _channel = null;
          _subscription?.cancel();
          _subscription = null;
          _connectionStateController.add(false);
          _onError(e);
        },
        onDone: () {
          _channel = null;
          _subscription?.cancel();
          _subscription = null;
          _connectionStateController.add(false);
          _onDone();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _channel = null;
      _subscription?.cancel();
      _subscription = null;
      _connectionStateController.add(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = CustomJsonUtil.decode(data);
      if (decoded is Map<String, dynamic>) {
        _connectionStateController.add(true);
        _messageController.add(decoded);
      }
    } catch (_) {}
  }

  void _onError(dynamic error) {
    if (!_closed) _scheduleReconnect();
  }

  void _onDone() {
    if (!_closed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _sessionToken == null) return;

    final delay = (_initialReconnectDelayMs * (1 << _reconnectAttempts))
        .clamp(_initialReconnectDelayMs, _maxReconnectDelayMs);
    _reconnectAttempts++;

    Future.delayed(Duration(milliseconds: delay), () {
      if (!_closed && _sessionToken != null) {
        _connectInternal();
      }
    });
  }

  /// 메시지 전송
  Future<void> send(Map<String, dynamic> message) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(CustomJsonUtil.encode(message) ?? '{}');
    } catch (_) {}
  }

  /// JOIN_BOARD
  Future<void> joinBoard(int boardId, {String? reqId}) async {
    await send({
      'type': 'JOIN_BOARD',
      if (reqId != null) 'req_id': reqId,
      'data': {'board_id': boardId},
    });
  }

  /// LEAVE_BOARD
  Future<void> leaveBoard(int boardId, {String? reqId}) async {
    await send({
      'type': 'LEAVE_BOARD',
      if (reqId != null) 'req_id': reqId,
      'data': {'board_id': boardId},
    });
  }

  /// CARD_MOVE - 카드 이동 (컬럼/순서 변경)
  Future<void> moveCard({
    required int boardId,
    required int cardId,
    required int toColumnId,
    int? beforeCardId,
    int? afterCardId,
    int? position,
    String? reqId,
  }) async {
    await send({
      'type': 'CARD_MOVE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
        'to_column_id': toColumnId,
        if (beforeCardId != null) 'before_card_id': beforeCardId,
        if (afterCardId != null) 'after_card_id': afterCardId,
        if (position != null) 'position': position,
      },
    });
  }

  /// CARD_CREATE - 카드 생성
  Future<void> createCard({
    required int boardId,
    required int columnId,
    required String title,
    String? description,
    String priority = 'medium',
    String? reqId,
  }) async {
    await send({
      'type': 'CARD_CREATE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'column_id': columnId,
        'title': title,
        'description': description ?? '',
        'priority': priority,
      },
    });
  }

  /// CARD_UPDATE - 카드 수정
  Future<void> updateCard({
    required int boardId,
    required int cardId,
    required Map<String, dynamic> patch,
    String? reqId,
  }) async {
    await send({
      'type': 'CARD_UPDATE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
        'patch': patch,
      },
    });
  }

  /// CARD_ARCHIVE - 카드 아카이브
  Future<void> archiveCard({
    required int boardId,
    required int cardId,
    String? reqId,
  }) async {
    await send({
      'type': 'CARD_ARCHIVE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
      },
    });
  }

  /// LOCK_ACQUIRE - 카드 편집 락 획득
  Future<void> acquireLock({
    required int boardId,
    required int cardId,
    String? reqId,
  }) async {
    await send({
      'type': 'LOCK_ACQUIRE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
      },
    });
  }

  /// LOCK_RENEW - 카드 편집 락 갱신
  Future<void> renewLock({
    required int boardId,
    required int cardId,
    String? reqId,
  }) async {
    await send({
      'type': 'LOCK_RENEW',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
      },
    });
  }

  /// LOCK_RELEASE - 카드 편집 락 해제
  Future<void> releaseLock({
    required int boardId,
    required int cardId,
    String? reqId,
  }) async {
    await send({
      'type': 'LOCK_RELEASE',
      if (reqId != null) 'req_id': reqId,
      'data': {
        'board_id': boardId,
        'card_id': cardId,
      },
    });
  }

  /// 연결 종료
  Future<void> disconnect() async {
    _closed = true;
    _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _sessionToken = null;
  }

  /// 리소스 해제
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
