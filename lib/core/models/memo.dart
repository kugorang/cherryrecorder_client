import '../database/database_helper.dart';

class Memo {
  final String? id;
  final String placeId;
  final String content;
  final String? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Memo({
    this.id,
    required this.placeId,
    required this.content,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Memo copyWith({
    String? id,
    String? placeId,
    String? content,
    String? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeId': placeId,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String?,
      placeId: json['placeId'] as String,
      content: json['content'] as String,
      tags: json['tags'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseHelper.columnId: id,
      DatabaseHelper.columnPlaceId: placeId,
      DatabaseHelper.columnContent: content,
      DatabaseHelper.columnTags: tags,
    };
  }

  factory Memo.fromMap(Map<String, dynamic> map) {
    return Memo(
      id: map[DatabaseHelper.columnId] as String?,
      placeId: map[DatabaseHelper.columnPlaceId] as String,
      content: map[DatabaseHelper.columnContent] as String,
      tags: map[DatabaseHelper.columnTags] as String?,
      createdAt:
          map[DatabaseHelper.columnCreatedAt] != null
              ? DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String)
              : DateTime.now(),
      updatedAt:
          map[DatabaseHelper.columnUpdatedAt] != null
              ? DateTime.parse(map[DatabaseHelper.columnUpdatedAt] as String)
              : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Memo{id: $id, placeId: $placeId, content: $content, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
