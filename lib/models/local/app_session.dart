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
    );
  }

  AppUser toUser() {
    return AppUser(id: userId, name: name, email: email, roles: roles);
  }

  AppSession copyWith({
    String? token,
    int? userId,
    String? name,
    String? email,
    List<String>? roles,
    DateTime? savedAt,
  }) {
    return AppSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      savedAt: savedAt ?? this.savedAt,
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
