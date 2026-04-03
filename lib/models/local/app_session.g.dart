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
      phone: fields[6] as String?,
      gender: fields[7] as String?,
      profilePhotoUrl: fields[8] as String?,
      mustChangePassword: fields[9] == null ? false : fields[9] as bool,
      phoneVerifiedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSession obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.savedAt)
      ..writeByte(6)
      ..write(obj.phone)
      ..writeByte(7)
      ..write(obj.gender)
      ..writeByte(8)
      ..write(obj.profilePhotoUrl)
      ..writeByte(9)
      ..write(obj.mustChangePassword)
      ..writeByte(10)
      ..write(obj.phoneVerifiedAt);
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
