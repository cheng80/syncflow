// board.dart
// 보드, 컬럼, 카드 모델

import 'package:flutter/material.dart';

/// 보드 목록 항목
class BoardItem {
  const BoardItem({
    required this.id,
    required this.title,
    required this.ownerId,
    this.createdAt,
  });

  factory BoardItem.fromJson(Map<String, dynamic> j) => BoardItem(
    id: j['id'] as int,
    title: j['title'] as String,
    ownerId: j['owner_id'] as int,
    createdAt: j['created_at'] as String?,
  );

  final int id;
  final String title;
  final int ownerId;
  final String? createdAt;
}

/// BoardDetail - 보드 상세 (컬럼 + 카드)
class BoardDetail {
  const BoardDetail({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.columns,
    required this.cards,
    this.boardVersion,
  });

  factory BoardDetail.fromJson(Map<String, dynamic> j) => BoardDetail(
    id: j['id'] as int,
    title: j['title'] as String,
    ownerId: j['owner_id'] as int,
    boardVersion: (j['board_version'] as num?)?.toInt(),
    columns: (j['columns'] as List)
        .map((e) => ColumnItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    cards: (j['cards'] as List)
        .map((e) => CardItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String title;
  final int ownerId;
  final List<ColumnItem> columns;
  final List<CardItem> cards;
  final int? boardVersion;
}

/// 컬럼
class ColumnItem {
  const ColumnItem({
    required this.id,
    required this.title,
    required this.position,
    this.isDone = false,
  });

  factory ColumnItem.fromJson(Map<String, dynamic> j) => ColumnItem(
    id: j['id'] as int,
    title: j['title'] as String,
    position: j['position'] as int,
    isDone: j['is_done'] as bool? ?? false,
  );

  final int id;
  final String title;
  final int position;
  final bool isDone;
}

/// 카드
class CardItem {
  const CardItem({
    required this.id,
    required this.columnId,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    this.assigneeId,
    this.dueDate,
    this.status = 'active',
    this.position = 0,
    this.mentionedUserIds = const [],
  });

  factory CardItem.fromJson(Map<String, dynamic> j) => CardItem(
    id: j['id'] as int,
    columnId: j['column_id'] as int,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    priority: j['priority'] as String? ?? 'medium',
    assigneeId: j['assignee_id'] as int?,
    dueDate: j['due_date'] as String?,
    status: j['status'] as String? ?? 'active',
    position: j['position'] as int? ?? 0,
    mentionedUserIds:
        (j['mentioned_user_ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
  );

  CardItem copyWith({
    int? id,
    int? columnId,
    String? title,
    String? description,
    String? priority,
    int? assigneeId,
    String? dueDate,
    String? status,
    int? position,
    List<int>? mentionedUserIds,
  }) => CardItem(
    id: id ?? this.id,
    columnId: columnId ?? this.columnId,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    assigneeId: assigneeId ?? this.assigneeId,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    position: position ?? this.position,
    mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
  );

  final int id;
  final int columnId;
  final String title;
  final String description;
  final String priority;
  final int? assigneeId;
  final String? dueDate;
  final String status;
  final int position;
  final List<int> mentionedUserIds;

  /// priority 색상
  Color get priorityColor {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
