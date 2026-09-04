import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../main.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../models/wound.dart';
import '../services/api_client.dart';
import '../services/assessment_service.dart';
import '../services/wound_service.dart';
import '../widgets/app_ui.dart';
import 'body_location_screen.dart';

/// 患者详情页：患者信息 + 部位列表。
/// 点击部位进入部位详情（含评估历史 + 数值曲线）。
/// 底部"新增记录"支持选择已有部位或新增部位。
class PatientDetailScreen extends StatefulWidget {
  final Patient patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with RouteAware {
  final WoundService _woundService = WoundService(apiClient: ApiClient.instance);
  final AssessmentService _assessmentService =
      AssessmentService(apiClient: ApiClient.instance);
  List<Wound>? _wounds;
  String? _error;
  final Set<String> _pendingSignWoundIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // 从下级页面（评估/签名等）返回时刷新，同步"待签名"角标。
    _load();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _wounds = null;
      _error = null;
    });
    final result = await _woundService.getWounds(widget.patient.id);
    if (!mounted) return;
    setState(() {
      _wounds = result.success ? (result.data ?? []) : [];
      _error = result.success ? null : result.message;
    });
    // 并行加载各部位评估记录，标记存在"待签名"记录的部位。
    if (result.success) {
      final futures = (result.data ?? [])
          .map((w) => _assessmentService.getAssessments(w.id));
      final results = await Future.wait(futures);
      if (!mounted) return;
      final pending = <String>{};
      for (final r in results) {
        if (!r.success) continue;
        for (final a in r.data ?? []) {
          if (a.status == AssessmentStatus.pendingSignature) {
            pending.add(a.woundId);
          }
        }
      }
      setState(() => _pendingSignWoundIds
        ..clear()
        ..addAll(pending));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.patient.displayLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _showToast('更多操作（开发中）'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            onPressed: _showAddRecordSheet,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新增记录'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_wounds == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.actionBlue));
    }
    if (_error != null) {
      return Center(child: Text('加载失败: $_error', style: AppTheme.caption));
    }

    return RefreshIndicator(
      color: AppTheme.actionBlue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildPatientCard(),
          const SizedBox(height: 20),
          const SectionTitle('已有创面'),
          const SizedBox(height: 12),
          if (_wounds!.isEmpty)
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('暂无创面记录', style: AppTheme.caption),
                ),
              ),
            )
          else
            for (final w in _wounds!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildWoundCard(w),
              ),
        ],
      ),
    );
  }

  Widget _buildPatientCard() {
    final p = widget.patient;
    final age = _age(p.dateOfBirth);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.displayLabel,
                  style: AppTheme.title.copyWith(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '${_genderLabel(p)}${age != null ? ' · $age 岁' : ''}',
                style: AppTheme.caption,
              ),
              const SizedBox(width: 8),
              const TypeChip(label: '住院', selected: true),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('病案号', p.medicalRecordNo ?? '—'),
          _infoRow('床位', '创伤骨科 3 床'),
          _infoRow('入院诊断', '压力性损伤'),
          _infoRow('入院日期', _fmtDate(p.createdAt)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: AppTheme.micro),
            ),
            Expanded(child: Text(value, style: AppTheme.caption)),
          ],
        ),
      );

  Widget _buildWoundCard(Wound w) {
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        '/wound-detail',
        arguments: w.id,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.pageBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(Icons.healing_rounded,
                color: AppTheme.textHint, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(w.anatomicalLocation,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (_pendingSignWoundIds.contains(w.id)) ...[
                      const SizedBox(width: 6),
                      const StatusChip.pendingSign(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(w.woundType ?? '—', style: AppTheme.micro),
                const SizedBox(height: 2),
                Text('起病 ${_fmtDate(w.onsetDate)}', style: AppTheme.micro),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textHint, size: 22),
        ],
      ),
    );
  }

  void _showAddRecordSheet() {
    final wounds = _wounds ?? const <Wound>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('新增记录', style: AppTheme.title),
              const SizedBox(height: 4),
              Text('选择要记录的部位', style: AppTheme.caption),
              const SizedBox(height: 16),
              if (wounds.isNotEmpty) ...[
                Text('已有部位', style: AppTheme.micro),
                const SizedBox(height: 8),
                for (final w in wounds)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.pageBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.healing_rounded,
                          color: AppTheme.textHint, size: 20),
                    ),
                    title: Text(w.anatomicalLocation,
                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(w.woundType ?? '', style: AppTheme.micro),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textHint, size: 20),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _goCapture(w);
                    },
                  ),
                const Divider(height: 24),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.actionBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_location_alt_outlined,
                      color: AppTheme.actionBlue, size: 20),
                ),
                title: const Text('新部位',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.actionBlue)),
                subtitle: Text('以图形方式选择身体部位', style: AppTheme.micro),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.actionBlue, size: 20),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _goNewLocation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goCapture(Wound wound) {
    Navigator.pushNamed(context, '/capture', arguments: {
      'patientId': widget.patient.id,
      'woundId': wound.id,
      'patientName': widget.patient.displayLabel,
    });
  }

  void _goNewLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BodyLocationScreen(
          patientId: widget.patient.id,
          patientName: widget.patient.displayLabel,
        ),
      ),
    );
  }

  int? _age(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _genderLabel(Patient p) {
    switch (p.gender) {
      case 'male':
      case 'M':
      case '男':
        return '男';
      case 'female':
      case 'F':
      case '女':
        return '女';
      default:
        return '—';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
