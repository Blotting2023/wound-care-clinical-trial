/// MenuGuard — 客户端按角色过滤菜单的 wrapper。
///
/// 用法：把 _MenuItem / _Card / _ListTile 包在 MenuGuard 里，按 role 决定
/// 是否渲染。服务端权限检查是兜底（防绕过），客户端只是减少视觉噪音。
library;

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/user_role.dart';

class MenuGuard extends StatelessWidget {
  /// 当前用户（来自 AuthProvider）
  final User? user;

  /// 可见所需的角色集合（满足任一即可）
  final List<UserRole> allowedRoles;

  /// 可见所需的权限（满足任一即可）
  final List<String> requiredPermissions;

  /// 可见所需的菜单 key（从 RolePermissionMatrix.visibleMenuKeys 取）
  final String? menuKey;

  /// 通过时渲染的内容
  final Widget child;

  /// 不可见时是否完全隐藏（默认）还是渲染为禁用态
  final bool hideWhenForbidden;

  /// 不可见时给的提示（仅在 hideWhenForbidden=false 生效）
  final String? forbiddenHint;

  const MenuGuard({
    super.key,
    required this.user,
    this.allowedRoles = const [],
    this.requiredPermissions = const [],
    this.menuKey,
    required this.child,
    this.hideWhenForbidden = true,
    this.forbiddenHint,
  });

  bool _isAllowed() {
    if (user == null) return false;
    // Admin 通配
    if (user!.permissions.contains('*')) return true;
    if (allowedRoles.isNotEmpty && !allowedRoles.contains(user!.role)) {
      return false;
    }
    if (requiredPermissions.isNotEmpty) {
      final ok = requiredPermissions
          .any((p) => user!.permissions.contains(p));
      if (!ok) return false;
    }
    if (menuKey != null) {
      final visible = RolePermissionMatrix.visibleMenuKeys(user!.role);
      if (!visible.contains(menuKey)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isAllowed()) return child;
    if (hideWhenForbidden) return const SizedBox.shrink();
    // 渲染为禁用 + 提示
    return Opacity(
      opacity: 0.4,
      child: Tooltip(
        message: forbiddenHint ?? '当前角色无权访问',
        child: IgnorePointer(child: child),
      ),
    );
  }
}
