import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
  });

  final int? id;
  final String name;
  final String email;
  final List<String> roles;

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
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'roles': roles};
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
  List<Object?> get props => [id, name, email, roles];
}
