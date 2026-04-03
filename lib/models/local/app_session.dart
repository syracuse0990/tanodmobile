import 'package:hive_flutter/hive_flutter.dart';
import 'package:tanodmobile/models/domain/app_user.dart';

part 'app_session.g.dart';

@HiveType(typeId: 0)
class AppSession extends HiveObject {
  AppSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.roles,
    required this.savedAt,
    this.phone,
    this.gender,
    this.profilePhotoUrl,
    this.mustChangePassword = false,
    this.phoneVerifiedAt,
  });

  @HiveField(0)
  final String token;

  @HiveField(1)
  final int? userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String email;

  @HiveField(4)
  final List<String> roles;

  @HiveField(5)
  final DateTime savedAt;

  @HiveField(6)
  final String? phone;

  @HiveField(7)
  final String? gender;

  @HiveField(8)
  final String? profilePhotoUrl;

  @HiveField(9, defaultValue: false)
  final bool mustChangePassword;

  @HiveField(10)
  final DateTime? phoneVerifiedAt;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    final token =
        json['token']?.toString() ?? json['access_token']?.toString() ?? '';
    final user = _resolveUserPayload(json);
    final userModel = AppUser.fromJson(user);

    return AppSession(
      token: token,
      userId: userModel.id,
      name: userModel.name,
      email: userModel.email,
      roles: userModel.roles,
      savedAt: DateTime.now(),
      phone: userModel.phone,
      gender: userModel.gender,
      profilePhotoUrl: userModel.profilePhotoUrl,
      mustChangePassword: userModel.mustChangePassword,
      phoneVerifiedAt: userModel.phoneVerifiedAt,
    );
  }

  AppUser toUser() {
    return AppUser(
      id: userId,
      name: name,
      email: email,
      roles: roles,
      phone: phone,
      gender: gender,
      profilePhotoUrl: profilePhotoUrl,
      mustChangePassword: mustChangePassword,
      phoneVerifiedAt: phoneVerifiedAt,
    );
  }

  AppSession copyWith({
    String? token,
    int? userId,
    String? name,
    String? email,
    List<String>? roles,
    DateTime? savedAt,
    String? phone,
    String? gender,
    String? profilePhotoUrl,
    bool? mustChangePassword,
    DateTime? phoneVerifiedAt,
  }) {
    return AppSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      savedAt: savedAt ?? this.savedAt,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
    );
  }

  static Map<String, dynamic> _resolveUserPayload(Map<String, dynamic> json) {
    final user = json['user'];

    if (user is Map<String, dynamic>) {
      return user;
    }

    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    final data = json['data'];

    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }

    if (data is Map && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }

    return json;
  }
}
