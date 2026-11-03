// GENERATED CODE - DO NOT MODIFY BY HAND
// NOTE: hand-updated for HiveField(8) (feedTypeName) because build_runner
// is unavailable in this environment. Field layout matches fav_history.dart;
// records written before this change have 8 fields, so fields[8] reads null.

part of 'fav_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavHistoryItemAdapter extends TypeAdapter<FavHistoryItem> {
  @override
  final int typeId = 0;

  @override
  FavHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavHistoryItem(
      id: fields[0] as String?,
      uid: fields[1] as String?,
      username: fields[2] as String?,
      userAvatar: fields[3] as String?,
      message: fields[4] as String?,
      device: fields[5] as String?,
      dateline: fields[6] as String?,
      time: (fields[7] as num?)?.toInt(),
      feedTypeName: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FavHistoryItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uid)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.userAvatar)
      ..writeByte(4)
      ..write(obj.message)
      ..writeByte(5)
      ..write(obj.device)
      ..writeByte(6)
      ..write(obj.dateline)
      ..writeByte(7)
      ..write(obj.time)
      ..writeByte(8)
      ..write(obj.feedTypeName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavHistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
