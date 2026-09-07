/// 当前登录的用户信息。
///
/// V1 demo 阶段，user 信息由后端 `/auth/login` 返回的 token 中内嵌的
/// payload 解出。生产环境应使用真正的 JWT 签名（HS256 / RS256）。
library;

import 'user_role.dart';

class User {
  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final List<String> centerIds;
  final List<String> permissions;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.centerIds = const [],
    this.permissions = const [],
  });

  /// 是否能看到真实姓名（PI / SubI / Admin 三角色）
  bool get canViewRealName =>
      role == UserRole.PI ||
      role == UserRole.SubI ||
      role == UserRole.Admin;

  /// JSON 反序列化（demo 后端返回结构）
  factory User.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'CRC';
    final role = UserRole.tryParse(roleStr) ?? UserRole.CRC;
    return User(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['username'] as String? ?? '',
      role: role,
      centerIds: (json['centerIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      permissions: (json['permissions'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          // 默认从矩阵补
          RolePermissionMatrix.permissionsOf(role),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'role': role.name,
        'centerIds': centerIds,
        'permissions': permissions,
      };

  User copyWith({
    String? displayName,
    UserRole? role,
    List<String>? centerIds,
    List<String>? permissions,
  }) =>
      User(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        centerIds: centerIds ?? this.centerIds,
        permissions: permissions ?? this.permissions,
      );
}
