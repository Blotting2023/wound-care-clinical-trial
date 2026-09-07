import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../services/api_client.dart';
import '../services/assessment_service.dart';
import '../services/consent_service.dart';
import '../services/permission_service.dart';
import '../services/wound_service.dart';
import '../utils/retention.dart';
import '../widgets/app_ui.dart';
import 'home_filter_screen.dart';

/// 工作台（设计稿 01）：问候头部 + 今日概览三宫格（可点进筛选列表）
/// + 新建评估主按钮 + 最近评估（真实数据，点击直达患者详情）。
class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoPatients;
  const HomeScreen({super.key, this.onGoPatients});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WoundService _woundService = WoundService(apiClient: ApiClient.instance);
  final AssessmentService _assessmentService =
      AssessmentService(apiClient: ApiClient.instance);
  final ConsentService _consentService =
      ConsentService(apiClient: ApiClient.instance);

  List<Assessment> _assessments = []; // 全部患者的评估记录
  final Map<String, Assessment> _latestByPatient = {};
  bool _loaded = false;
  bool _loadingStats = false;

  /// IRB 视图：待审 consent 列表（受试者已脱敏为鉴认代码）
  List<Map<String, dynamic>> _consents = [];
  bool _loadingConsents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loadingStats = true);
    final patientProvider = context.read<PatientProvider>();
    await patientProvider.loadAll();
    if (!mounted) return;

    // 汇总：患者 → 部位 → 评估记录。
    final all = <Assessment>[];
    for (final p in patientProvider.patients) {
      final woundsResult = await _woundService.getWounds(p.id);
      if (!woundsResult.success) continue;
      for (final w in woundsResult.data ?? []) {
        final aResult = await _assessmentService.getAssessments(w.id);
        if (!aResult.success) continue;
        all.addAll(aResult.data ?? []);
      }
    }
    if (!mounted) return;

    final latest = <String, Assessment>{};
    for (final a in all) {
      final prev = latest[a.patientId];
      if (prev == null || a.createdAt.isAfter(prev.createdAt)) {
        latest[a.patientId] = a;
      }
    }

    // W4.6 — IRB 视图需要看待审 consent 队列
    List<Map<String, dynamic>> consentList = [];
    if (mounted) {
      final role = context.read<AuthProvider>().user?.role;
      if (role == UserRole.IRB) {
        setState(() => _loadingConsents = true);
        final r = await _consentService.listAll(status: 'pending');
        if (r.success) consentList = r.data ?? [];
        if (mounted) setState(() => _loadingConsents = false);
      }
    }

    if (!mounted) return;
    setState(() {
      _assessments = all..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _latestByPatient
        ..clear()
        ..addAll(latest);
      _consents = consentList;
      _loaded = true;
      _loadingStats = false;
    });
  }

  int _count(HomeFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case HomeFilter.pendingAssess:
        return _assessments
            .where((a) => a.status == AssessmentStatus.draft)
            .length;
      case HomeFilter.pendingSign:
        return _assessments
            .where((a) => a.status == AssessmentStatus.pendingSignature)
            .length;
      case HomeFilter.todayFollowUp:
        return _assessments.where((a) {
          final d = a.createdAt;
          return DateTime(d.year, d.month, d.day).isAtSameMomentAs(today);
        }).length;
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String get _todayLabel {
    final now = DateTime.now();
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.month}月${now.day}日 星期${weeks[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.actionBlue,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (role == UserRole.IRB) ..._buildIrbBody(),
              if (role == UserRole.Sponsor) ..._buildSponsorBody(),
              if (role == UserRole.Admin) ..._buildAdminBody(),
              if (role == UserRole.PI ||
                  role == UserRole.SubI ||
                  role == UserRole.CRC) ...[
                _buildOverview(),
                const SizedBox(height: 20),
                _buildPrimaryAction(),
                const SizedBox(height: 12),
                _buildRoleHint(),
                const SizedBox(height: 24),
                const SectionTitle('最近评估'),
                const SizedBox(height: 12),
                _buildRecentList(),
                const SizedBox(height: 20),
                _buildRetentionBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// IRB 专属视图：只看待审 consent 队列，不看临床评估。
  /// 数据范围：受试者已脱敏为鉴认代码 + 中心编号 + 通道 + 签署日期。
  List<Widget> _buildIrbBody() {
    return [
      _buildRoleHint(),
      const SizedBox(height: 20),
      _irbOverview(),
      const SizedBox(height: 24),
      const SectionTitle('待审 eConsent'),
      const SizedBox(height: 12),
      _irbConsentList(),
    ];
  }

  Widget _irbOverview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.actionBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_outlined, color: AppTheme.actionBlue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IRB 伦理审阅视图',
                    style: AppTheme.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '数据范围：知情同意书 + SAE 报告 + 方案偏离；不含临床评估明细',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _irbConsentList() {
    if (_loadingConsents) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_consents.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('暂无待审 eConsent', style: AppTheme.caption),
        ),
      );
    }
    return Column(
      children: [
        for (final c in _consents.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c['mode'] == 'E_CONSENT'
                              ? AppTheme.actionBlue
                              : AppTheme.statusPendingSign,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c['mode'] == 'E_CONSENT' ? 'A 通道' : 'B 通道',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('受试者 ${c['subjectCode'] ?? c['patientId']}',
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('中心 ${c['centerId'] ?? '—'}',
                          style: AppTheme.caption),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '签署 ${_fmtDate(c['signedAt'])} · v${c['version'] ?? '1.0'}',
                    style: AppTheme.micro,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Sponsor 监查视图：试验进度统计卡（聚合），不见个体。
  List<Widget> _buildSponsorBody() {
    final pending = _assessments
        .where((a) =>
            a.status == AssessmentStatus.draft ||
            a.status == AssessmentStatus.pendingSignature)
        .length;
    final locked =
        _assessments.where((a) => a.status == AssessmentStatus.locked).length;
    final totalPatients = context.watch<PatientProvider>().patients.length;
    return [
      _buildRoleHint(),
      const SizedBox(height: 20),
      const SectionTitle('试验进度统计（聚合）'),
      const SizedBox(height: 12),
      _metricGrid([
        ('受试者总数', '$totalPatients'),
        ('已锁定评估', '$locked'),
        ('进行中评估', '$pending'),
        ('中心数', '1'),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.actionBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined,
                color: AppTheme.actionBlue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '申办方仅可查看脱敏汇总数据。个体受试者字段（姓名/病案号/创面图像）均已隐藏 — 符合 GCP 数据最小化原则。',
                style: AppTheme.caption,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Admin 系统管理视图：多中心状态 + 系统任务入口。
  List<Widget> _buildAdminBody() {
    return [
      _buildRoleHint(),
      const SizedBox(height: 20),
      const SectionTitle('系统管理'),
      const SizedBox(height: 12),
      _adminTasks(),
    ];
  }

  Widget _adminTasks() {
    final tasks = [
      (Icons.account_tree_outlined, '多中心管理', '查看中心状态 / 切换 eConsent 通道'),
      (Icons.assignment_ind_outlined, '角色分配', '为每个中心分配 PI / SubI / CRC'),
      (Icons.devices_other, '器械追溯', '查看试验器械台账 + 中心归属'),
      (Icons.history, '审计追踪', '全量操作日志（who/when/before→after）'),
    ];
    return Column(
      children: [
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Icon(t.$1, color: AppTheme.actionBlue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$2,
                            style: AppTheme.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.$3, style: AppTheme.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textHint),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricGrid(List<(String label, String value)> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 32, color: AppTheme.cardBorder),
            Expanded(
              child: Column(
                children: [
                  Text(items[i].$2,
                      style: AppTheme.metricNumber
                          .copyWith(color: AppTheme.actionBlue)),
                  const SizedBox(height: 4),
                  Text(items[i].$1, style: AppTheme.caption),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// W5.1 — GCP 数据留存期标识横幅（NMPA 2022 §63：试验完成后 10 年）
  Widget _buildRetentionBanner() {
    DateTime? latest;
    for (final a in _assessments) {
      final t = a.signedAt ?? a.createdAt;
      if (latest == null || t.isAfter(latest)) latest = t;
    }
    final badge = RetentionBadge(latest);
    final color = badge.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_outlined, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GCP 数据完整性',
                    style: AppTheme.body
                        .copyWith(fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text(badge.fullLabel, style: AppTheme.caption),
                const SizedBox(height: 2),
                Text(
                  '依据《医疗器械 GCP》（NMPA 2022 年第 28 号）第八章第 63 条 + ALCOA+ Enduring',
                  style: AppTheme.micro,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso as String);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    final name = auth.displayName ?? '李医生';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting，$name', style: AppTheme.title),
              const SizedBox(height: 2),
              Text(_todayLabel, style: AppTheme.caption),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              size: 26, color: AppTheme.textSecondary),
          onPressed: () => _showToast('通知中心（开发中）'),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.actionBlue.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name.characters.first : '医',
            style: const TextStyle(
                color: AppTheme.actionBlue, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// 今日概览：真实统计，点击可进入对应记录列表。
  Widget _buildOverview() {
    final items = [
      (filter: HomeFilter.pendingAssess, label: '待评估'),
      (filter: HomeFilter.pendingSign, label: '待签名'),
      (filter: HomeFilter.todayFollowUp, label: '今日随访'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 32, color: AppTheme.cardBorder),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openFilter(items[i].filter),
                child: Column(
                  children: [
                    Text(_loaded ? '${_count(items[i].filter)}' : '—',
                        style: AppTheme.metricNumber),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(items[i].label, style: AppTheme.caption),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 14, color: AppTheme.textHint),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openFilter(HomeFilter filter) {
    final patients = context.read<PatientProvider>().patients;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeFilterScreen(
          filter: filter,
          allAssessments: _assessments,
          patients: patients,
        ),
      ),
    );
  }

  Widget _buildPrimaryAction() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canCreate =
        PermissionService.instance.can(user, Permission.assessmentCreate);
    if (!canCreate) {
      // 只读角色不显示主操作按钮 — GCP 要求"两个研究者之外只能查看"。
      return const SizedBox.shrink();
    }
    return ElevatedButton.icon(
      onPressed: () {
        if (widget.onGoPatients != null) widget.onGoPatients!();
      },
      style: ElevatedButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text('新建创面评估'),
    );
  }

  /// 给只读角色一个身份提示卡 — 说明"你当前角色是 X，只能查看相关数据"。
  Widget _buildRoleHint() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final canCreate =
        PermissionService.instance.can(user, Permission.assessmentCreate);
    if (canCreate) return const SizedBox.shrink();

    final role = user.role;
    final String tip;
    final IconData icon;
    final Color tint;
    switch (role) {
      case UserRole.CRC:
        tip =
            '当前为临床研究协调员。按 GCP 2020+ 指南，创面打分等医学判断由 PI/Sub-I 完成；如需录入合并用药/合并疾病等非医学字段，请联系 PI 申请授权。';
        icon = Icons.assignment_ind_outlined;
        tint = AppTheme.statusPendingSign;
        break;
      case UserRole.IRB:
        tip = '当前为伦理委员会。可审阅知情同意书与 SAE 报告；不参与临床数据录入。';
        icon = Icons.gavel_outlined;
        tint = AppTheme.actionBlue;
        break;
      case UserRole.Sponsor:
        tip = '当前为申办方。监查视图可查看审计追踪与汇总统计；受试者个体信息按 GCP 仅展示脱敏字段。';
        icon = Icons.fact_check_outlined;
        tint = AppTheme.actionBlue;
        break;
      case UserRole.Admin:
        tip = '当前为系统管理员。系统配置 / 多中心 / 器械追溯等管理项已在【我的】-【试验管理】；临床数据录入由 PI/Sub-I 完成。';
        icon = Icons.admin_panel_settings_outlined;
        tint = AppTheme.statusLocked;
        break;
      case UserRole.PI:
      case UserRole.SubI:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tip,
                style: AppTheme.caption.copyWith(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  /// 最近评估：真实患者 + 该患者最新记录状态，点击直达患者详情页。
  Widget _buildRecentList() {
    return Consumer<PatientProvider>(
      builder: (_, provider, __) {
        if (!_loaded || _loadingStats) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingStats
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('暂无评估记录', style: AppTheme.caption),
              ),
            ),
          );
        }

        // 有记录的患者按最新记录时间倒序，取前 3 位；其余补在后面。
        final withRecords = provider.patients
            .where((p) => _latestByPatient.containsKey(p.id))
            .toList()
          ..sort((a, b) => _latestByPatient[b.id]!.createdAt
              .compareTo(_latestByPatient[a.id]!.createdAt));
        final withoutRecords = provider.patients
            .where((p) => !_latestByPatient.containsKey(p.id))
            .toList();
        final ordered = [...withRecords, ...withoutRecords];
        final shown = ordered.take(3).toList();

        if (shown.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('暂无患者', style: AppTheme.caption),
            ),
          );
        }

        return Column(
          children: [
            for (final p in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => Navigator.pushNamed(
                      context, '/patient-detail',
                      arguments: p),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(p.displayLabel,
                                    style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                _recentStatusChip(p.id),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '病案号 ${p.medicalRecordNo ?? '—'}',
                              style: AppTheme.micro,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textHint, size: 22),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _recentStatusChip(String patientId) {
    final latest = _latestByPatient[patientId];
    if (latest == null) return const SizedBox.shrink();
    switch (latest.status) {
      case AssessmentStatus.draft:
        return StatusChip.custom(label: '待评估');
      case AssessmentStatus.pendingSignature:
        return const StatusChip.pendingSign();
      case AssessmentStatus.locked:
        return const StatusChip.locked();
      case AssessmentStatus.archived:
        return StatusChip.custom(label: '已归档');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
