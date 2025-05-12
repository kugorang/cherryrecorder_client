// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoAdapter extends TypeAdapter<Memo> {
  @override
  final int typeId = 1;

  @override
  Memo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // latitude와 longitude를 안전하게 처리
    double latitude;
    double longitude;

    // 위도 처리
    if (fields[2] is double) {
      latitude = fields[2] as double;
    } else if (fields[2] is String) {
      latitude = double.parse(fields[2] as String);
    } else if (fields[2] is int) {
      latitude = (fields[2] as int).toDouble();
    } else {
      latitude = 0.0; // 기본값
    }

    // 경도 처리
    if (fields[3] is double) {
      longitude = fields[3] as double;
    } else if (fields[3] is String) {
      longitude = double.parse(fields[3] as String);
    } else if (fields[3] is int) {
      longitude = (fields[3] as int).toDouble();
    } else {
      longitude = 0.0; // 기본값
    }

    return Memo(
      id: fields[0] as String?,
      placeId: fields[1] as String,
      latitude: latitude,
      longitude: longitude,
      content: fields[4] as String,
      tags: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Memo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.placeId)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
