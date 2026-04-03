import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.phone,
    this.gender,
    this.profilePhotoUrl,
    this.mustChangePassword = false,
    this.phoneVerifiedAt,
  });

  final int? id;
  final String name;
  final String email;
  final List<String> roles;
  final String? phone;
  final String? gender;
  final String? profilePhotoUrl;
  final bool mustChangePassword;
  final DateTime? phoneVerifiedAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dynamic rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles
              .map((dynamic role) {
                if (role is Map<String, dynamic>) {
                  return role['name']?.toString() ?? '';
                }

                if (role is Map) {
                  return role['name']?.toString() ?? '';
                }

                return role.toString();
              })
              .where((role) => role.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return AppUser(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? 'Tanod User',
      email: json['email']?.toString() ?? '',
      roles: roles,
      phone: json['phone']?.toString(),
      gender: json['gender']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      mustChangePassword: json['must_change_password'] == true,
      phoneVerifiedAt: json['phone_verified_at'] != null
          ? DateTime.tryParse(json['phone_verified_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'roles': roles,
      'phone': phone,
      'gender': gender,
      'profile_photo_url': profilePhotoUrl,
      'must_change_password': mustChangePassword,
      'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, name, email, roles, phone, gender, profilePhotoUrl, mustChangePassword, phoneVerifiedAt];
}
