import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../providers/patient_provider.dart';
import '../services/api_client.dart';
import '../services/assessment_service.dart';
import '../services/wound_service.dart';
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

  List<Assessment> _assessments = []; // 全部患者的评估记录
  final Map<String, Assessment> _latestByPatient = {};
  bool _loaded = false;
  bool _loadingStats = false;

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

    setState(() {
      _assessments = all..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _latestByPatient
        ..clear()
        ..addAll(latest);
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
              _buildOverview(),
              const SizedBox(height: 20),
              _buildPrimaryAction(),
              const SizedBox(height: 24),
              const SectionTitle('最近评估'),
              const SizedBox(height: 12),
              _buildRecentList(),
            ],
          ),
        ),
      ),
    );
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
