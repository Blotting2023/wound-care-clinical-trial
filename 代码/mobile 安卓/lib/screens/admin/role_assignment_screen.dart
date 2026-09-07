import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_ui.dart';
/// Admin 专属页：演示用户 / 角色列表 + 一键切换演示角色。
///
/// V1 demo 阶段：每个角色只读展示一个 mock 用户，Admin 可"以该角色身份
/// 操作"，方便老胡秒切角色看不同菜单。
/// 生产环境这个页面就是真的"用户管理 + 角色分配"——本期只做 UI 骨架。
class RoleAssignmentScreen extends StatelessWidget {
  const RoleAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('角色分配（Admin）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'V1 Demo 说明',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '这是演示专用的角色切换器。生产环境的角色分配走机构 LDAP / IdP，'
                  '不允许终端用户自选。',
                  style: AppTheme.micro,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前角色：${currentUser?.role.displayName ?? '—'}'
                  '（${currentUser?.displayName ?? '未登录'}）',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.actionBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('6 角色 × 演示用户'),
          const SizedBox(height: 12),
          for (final role in UserRole.values) ...[
            _RoleCard(
              role: role,
              isCurrent: currentUser?.role == role,
              onSwitch: () => _onSwitch(context, role),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        size: 18, color: AppTheme.actionBlue),
                    const SizedBox(width: 8),
                    const Text('角色权限矩阵速查',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final role in UserRole.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${role.displayName}（${role.name}）：'
                      '${RolePermissionMatrix.permissionsOf(role).join(" / ")}',
                      style: AppTheme.micro,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSwitch(BuildContext context, UserRole role) async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.switchDemoRole(role);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 ${role.displayName}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败: $e')),
      );
    }
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool isCurrent;
  final VoidCallback onSwitch;
  const _RoleCard({
    required this.role,
    required this.isCurrent,
    required this.onSwitch,
  });

  Color get _accent {
    switch (role) {
      case UserRole.PI:
        return AppTheme.actionBlue;
      case UserRole.SubI:
        return Colors.indigo;
      case UserRole.CRC:
        return Colors.teal;
      case UserRole.Sponsor:
        return Colors.deepOrange;
      case UserRole.IRB:
        return Colors.purple;
      case UserRole.Admin:
        return AppTheme.statusLocked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(_iconFor(role), color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(role.displayName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    TypeChip(label: role.name, selected: isCurrent),
                    if (isCurrent) ...[
                      const SizedBox(width: 4),
                      const TypeChip(label: '当前', selected: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${RolePermissionMatrix.permissionsOf(role).length} 项权限',
                  style: AppTheme.micro,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: isCurrent ? null : onSwitch,
            child: Text(isCurrent ? '使用中' : '切换到此角色'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(UserRole role) {
    switch (role) {
      case UserRole.PI:
        return Icons.medical_services_rounded;
      case UserRole.SubI:
        return Icons.person_outline_rounded;
      case UserRole.CRC:
        return Icons.assignment_ind_rounded;
      case UserRole.Sponsor:
        return Icons.business_rounded;
      case UserRole.IRB:
        return Icons.gavel_rounded;
      case UserRole.Admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}
