// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSessionAdapter extends TypeAdapter<AppSession> {
  @override
  final int typeId = 0;

  @override
  AppSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSession(
      token: fields[0] as String,
      userId: fields[1] as int?,
      name: fields[2] as String,
      email: fields[3] as String,
      roles: (fields[4] as List).cast<String>(),
      savedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AppSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.token)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.roles)
      ..writeByte(5)
      ..write(obj.savedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
