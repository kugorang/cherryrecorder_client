import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

// Hive Type ID 정의
part 'memo.g.dart';

/// 메모의 우선순위를 나타내는 열거형.
@HiveType(typeId: 1)
enum MemoPriority {
  /// 낮음
  @HiveField(0)
  low,

  /// 보통
  @HiveField(1)
  medium,

  /// 높음
  @HiveField(2)
  high,
}

/// 지도 위의 특정 위치와 관련된 메모 정보를 저장하는 클래스.
@HiveType(typeId: 0)
class Memo extends HiveObject {
  /// 고유 식별자 (UUID v4).
  @HiveField(0)
  final String id;

  /// 메모 내용.
  @HiveField(1)
  String content;

  /// 메모가 연결된 장소의 위도.
  @HiveField(2)
  final double latitude;

  /// 메모가 연결된 장소의 경도.
  @HiveField(3)
  final double longitude;

  /// 메모 생성 날짜 및 시간.
  @HiveField(4)
  final DateTime createdAt;

  /// 메모 수정 날짜 및 시간.
  @HiveField(5)
  DateTime updatedAt;

  /// 메모 우선순위.
  @HiveField(6)
  MemoPriority priority;

  /// 메모에 첨부된 이미지 파일 경로 또는 URL 리스트.
  @HiveField(7)
  List<String> imagePaths;

  /// [Memo] 인스턴스를 생성한다.
  ///
  /// [id]가 제공되지 않으면 UUID v4로 자동 생성된다.
  /// [createdAt]과 [updatedAt]은 현재 시간으로 초기화된다.
  ///
  /// * [id]: 메모의 고유 ID (선택 사항).
  /// * [content]: 메모 내용.
  /// * [latitude]: 장소의 위도.
  /// * [longitude]: 장소의 경도.
  /// * [priority]: 메모 우선순위 (기본값: MemoPriority.medium).
  /// * [imagePaths]: 첨부 이미지 경로 리스트 (기본값: 빈 리스트).
  /// * [createdAt]: 생성 시간 (선택 사항, 기본값: 현재 시간).
  /// * [updatedAt]: 수정 시간 (선택 사항, 기본값: 현재 시간).
  Memo({
    String? id,
    required this.content,
    required this.latitude,
    required this.longitude,
    this.priority = MemoPriority.medium,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       imagePaths = imagePaths ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 위도와 경도를 [LatLng] 객체로 반환한다.
  LatLng get latLng => LatLng(latitude, longitude);

  // HiveObject를 상속받으므로 key 필드는 이미 존재함
  // String get key => id; // 불필요

  @override
  String toString() {
    return 'Memo(id: $id, content: "${content.substring(0, (content.length > 10 ? 10 : content.length))}", lat: $latitude, lng: $longitude, priority: $priority, createdAt: $createdAt)';
  }
}
