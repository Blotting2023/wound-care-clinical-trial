import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_ui.dart';
import 'audit_log_screen.dart';
import 'center_manage_screen.dart';
import 'device_inventory_screen.dart';
import 'protocol_manage_screen.dart';
import 'tutorial_screen.dart';

/// 「我的」页：账号信息 + 简易教程 / 服务器设置 / 退出登录。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _serverUrl;

  @override
  void initState() {
    super.initState();
    _serverUrl = ApiConfig.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 20),
          const SectionTitle('使用帮助'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.menu_book_rounded,
                  title: '简易教程',
                  subtitle: '7 步讲清一次完整创面评估',
                  color: AppTheme.actionBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TutorialScreen()),
                  ),
                ),
                const Divider(height: 20, color: AppTheme.cardBorder),
                _MenuItem(
                  icon: Icons.verified_user_outlined,
                  title: '合规说明',
                  subtitle: '电子签名 · 审计追踪 · 数据脱敏',
                  color: AppTheme.statusLocked,
                  onTap: () => _showComplianceDialog(),
                ),
                const Divider(height: 20, color: AppTheme.cardBorder),
                _MenuItem(
                  icon: Icons.fact_check_outlined,
                  title: '审计日志',
                  subtitle: 'GCP §57–63 · 哈希链完整性自检',
                  color: AppTheme.actionBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuditLogScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('试验管理'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.assignment_rounded,
                  title: '试验方案',
                  subtitle: '方案代号 / 版本 / 试验期 (GCP §A3)',
                  color: AppTheme.actionBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProtocolManageScreen()),
                  ),
                ),
                const Divider(height: 20, color: AppTheme.cardBorder),
                _MenuItem(
                  icon: Icons.local_hospital_rounded,
                  title: '研究中心',
                  subtitle: '分中心 IRB 备案与 PI 指派 (GCP §A3 多中心)',
                  color: AppTheme.actionBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CenterManageScreen()),
                  ),
                ),
                const Divider(height: 20, color: AppTheme.cardBorder),
                _MenuItem(
                  icon: Icons.inventory_2_rounded,
                  title: '器械库存台账',
                  subtitle: '批号 / 序列号 / 有效期 / 在用归还 (GCP §22)',
                  color: AppTheme.actionBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeviceInventoryScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('系统设置'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.pageBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dns_outlined,
                          size: 18, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Text('API 服务地址',
                        style: AppTheme.body.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: _serverUrl),
                  onChanged: (v) => _serverUrl = v.trim(),
                  decoration: InputDecoration(
                    hintText: 'http://host:8080/api',
                    hintStyle: AppTheme.micro,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                  style: AppTheme.caption,
                ),
                const SizedBox(height: 8),
                Text('演示模式：${ApiConfig.demoMode ? '开启（内存假数据）' : '关闭'}',
                    style: AppTheme.micro),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: _MenuItem(
              icon: Icons.logout_rounded,
              title: '退出登录',
              subtitle: '返回登录页',
              color: AppTheme.statusPendingSign,
              showChevron: false,
              onTap: () {
                context.read<AuthProvider>().logout();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('创面评估系统 V1 · 演示版本', style: AppTheme.micro),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.actionBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.person_rounded,
                size: 28, color: AppTheme.actionBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('演示护士（PI 视角）',
                    style: AppTheme.body
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text('demo-nurse-01 · 主要研究者', style: AppTheme.micro),
                const SizedBox(height: 2),
                Text('角色 PI / V1 演示', style: AppTheme.micro),
              ],
            ),
          ),
          const TypeChip(label: '已授权', selected: true),
        ],
      ),
    );
  }

  void _showComplianceDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合规说明'),
        content: const SingleChildScrollView(
          child: Text(
            '· 电子签名：每次评估需 6 位 PIN 签名，签名后记录锁定不可修改。\n\n'
            '· 审计追踪：创建、修改、签名、查看等操作全程留痕（21 CFR Part 11）。\n\n'
            '· 数据脱敏：患者身份信息与影像数据分离存储，遵循 PIPL 与 GCP 要求。\n\n'
            '· 只读回看：已锁定记录在任何页面均为只读，更正需走修订流程。',
            style: TextStyle(fontSize: 13, height: 1.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.micro),
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
        ],
      ),
    );
  }
}
