/// 权限检查服务 — 客户端预过滤 + 服务端兜底。
///
/// 客户端过滤只决定"菜单是否显示 / 按钮是否 enable"，真正的权威
/// 检查在 `DemoBackend._checkPermission`，所以即便客户端被绕过也
/// 不会越权操作数据。
library;

import '../models/user.dart';
import '../models/user_role.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// 检查当前用户是否拥有某权限。
  bool can(User? user, String permission) {
    if (user == null) return false;
    // Admin 通配
    if (user.permissions.contains('*')) return true;
    return user.permissions.contains(permission);
  }

  /// 显式角色检查
  bool isRole(User? user, UserRole role) => user?.role == role;

  bool isAnyOf(User? user, List<UserRole> roles) =>
      user != null && roles.contains(user.role);

  /// 菜单可见性快捷方法
  bool canSeeMenu(User? user, String menuKey) {
    if (user == null) return false;
    return RolePermissionMatrix.visibleMenuKeys(user.role).contains(menuKey);
  }

  /// 过滤菜单列表（保留顺序）
  List<T> filterMenus<T>(User? user, List<T> menus, String Function(T) keyOf) {
    if (user == null) return const [];
    final visible = RolePermissionMatrix.visibleMenuKeys(user.role);
    return menus.where((m) => visible.contains(keyOf(m))).toList();
  }
}
