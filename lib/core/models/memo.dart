import '../database/database_helper.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'memo.g.dart'; // Hive 코드 생성을 위한 부분 파일

@HiveType(typeId: 1)
class Memo {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String placeId;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final String content;

  @HiveField(5)
  final String? tags;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final String? placeName;

  Memo({
    String? id,
    required this.placeId,
    this.placeName,
    required this.latitude,
    required this.longitude,
    required this.content,
    this.tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Memo copyWith({
    String? id,
    String? placeId,
    String? placeName,
    double? latitude,
    double? longitude,
    String? content,
    String? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
      'placeName': placeName,
      'latitude': latitude,
      'longitude': longitude,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Memo.fromJson(Map<String, dynamic> json) {
    // latitude, longitude 값을 안전하게 처리
    double parseSafeDouble(dynamic value) {
      if (value == null) {
        return 0.0;
      } else if (value is double) {
        return value;
      } else if (value is int) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return Memo(
      id: json['id'] as String?,
      placeId: json['placeId'] as String,
      placeName: json['placeName'] as String?,
      latitude: parseSafeDouble(json['latitude']),
      longitude: parseSafeDouble(json['longitude']),
      content: json['content'] as String,
      tags: json['tags'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // SQLite 와 호환되는 toMap 메서드 - 레거시 지원
  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnPlaceId: placeId,
      'placeName': placeName,
      DatabaseHelper.columnContent: content,
      DatabaseHelper.columnTags: tags,
      DatabaseHelper.columnCreatedAt: createdAt.toIso8601String(),
      DatabaseHelper.columnUpdatedAt: updatedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // SQLite 호환 메서드 - 레거시 지원
  factory Memo.fromMap(Map<String, dynamic> map) {
    // 좌표 값 안전하게 파싱하는 헬퍼 함수
    double parseSafeDouble(dynamic value) {
      if (value == null) {
        return 0.0;
      } else if (value is double) {
        return value;
      } else if (value is int) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // 위도, 경도 값 안전하게 처리
    double latitude = parseSafeDouble(map['latitude']);
    double longitude = parseSafeDouble(map['longitude']);

    return Memo(
      id: map[DatabaseHelper.columnId] as String?,
      placeId: map[DatabaseHelper.columnPlaceId] as String,
      placeName: map['placeName'] as String?,
      latitude: latitude,
      longitude: longitude,
      content: map[DatabaseHelper.columnContent] as String,
      tags: map[DatabaseHelper.columnTags] as String?,
      createdAt: map[DatabaseHelper.columnCreatedAt] != null
          ? DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String)
          : DateTime.now(),
      updatedAt: map[DatabaseHelper.columnUpdatedAt] != null
          ? DateTime.parse(map[DatabaseHelper.columnUpdatedAt] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Memo{id: $id, placeId: $placeId, placeName: $placeName, latitude: $latitude, longitude: $longitude, content: $content, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
