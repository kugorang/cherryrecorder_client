// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoAdapter extends TypeAdapter<Memo> {
  @override
  final int typeId = 0;

  @override
  Memo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Memo(
      id: fields[0] as String?,
      content: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      priority: fields[6] as MemoPriority,
      imagePaths: (fields[7] as List?)?.cast<String>(),
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Memo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.imagePaths);
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

class MemoPriorityAdapter extends TypeAdapter<MemoPriority> {
  @override
  final int typeId = 1;

  @override
  MemoPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MemoPriority.low;
      case 1:
        return MemoPriority.medium;
      case 2:
        return MemoPriority.high;
      default:
        return MemoPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, MemoPriority obj) {
    switch (obj) {
      case MemoPriority.low:
        writer.writeByte(0);
        break;
      case MemoPriority.medium:
        writer.writeByte(1);
        break;
      case MemoPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
