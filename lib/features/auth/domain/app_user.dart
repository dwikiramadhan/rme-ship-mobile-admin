import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = userRoleFromApiValue(json['role'] as String?);
    if (role == null) {
      throw FormatException('Unknown role in login response: ${json['role']}');
    }
    return AppUser(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['nama'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.apiValue,
      };

  @override
  List<Object?> get props => [id, name, email, role];
}

class AuthSession extends Equatable {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromLoginResponse(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || userJson == null) {
      throw const FormatException('Login response missing token or user object.');
    }
    return AuthSession(token: token, user: AppUser.fromJson(userJson));
  }

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [token, user];
}
