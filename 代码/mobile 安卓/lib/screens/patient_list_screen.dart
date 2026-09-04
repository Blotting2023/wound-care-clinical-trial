import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../widgets/app_ui.dart';

/// 患者列表（设计稿 02）：标题 + 添加按钮、搜索框、筛选 chips、患者卡列表。
class PatientListScreen extends StatefulWidget {
  final bool embedded; // inside MainShell tab (no logout button)
  const PatientListScreen({super.key, this.embedded = false});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchCtrl = TextEditingController();
  int _filterIndex = 0;

  static const _filters = ['全部', '住院', '门诊', '随访中'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('患者'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded,
                color: AppTheme.actionBlue),
            onPressed: () => _showToast('新建患者（开发中）'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索姓名 / 病案号',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textHint),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppTheme.textHint),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search();
                        },
                      )
                    : null,
                isDense: true,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilterChipBar(
              labels: _filters,
              selectedIndex: _filterIndex,
              onSelected: (i) => setState(() => _filterIndex = i),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<PatientProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading && provider.patients.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.actionBlue));
                }
                if (provider.error != null) {
                  return Center(
                      child: Text('加载失败: ${provider.error}',
                          style: AppTheme.caption));
                }
                final patients = _filtered(provider.patients);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('患者 · ${patients.length}',
                          style: AppTheme.caption),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: patients.isEmpty
                          ? Center(
                              child: Text('未找到患者',
                                  style: AppTheme.caption))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: patients.length,
                              itemBuilder: (_, i) => _PatientCard(
                                patient: patients[i],
                                onTap: () => Navigator.pushNamed(
                                    context, '/patient-detail',
                                    arguments: patients[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Patient> _filtered(List<Patient> all) {
    // demo 数据暂无住院/门诊类型字段，非「全部」筛选下保留全部（占位演示）。
    return all;
  }

  void _search() => context.read<PatientProvider>().searchByName(_searchCtrl.text.trim());

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  const _PatientCard({required this.patient, required this.onTap});

  int? get _age {
    final dob = patient.dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String get _genderLabel {
    switch (patient.gender) {
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

  @override
  Widget build(BuildContext context) {
    final age = _age;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(patient.displayLabel,
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(
                        '$_genderLabel${age != null ? ' · $age 岁' : ''}',
                        style: AppTheme.micro,
                      ),
                      const SizedBox(width: 8),
                      const TypeChip(label: '住院', selected: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('病案号 ${patient.medicalRecordNo ?? '—'}',
                      style: AppTheme.micro),
                  const SizedBox(height: 2),
                  Text('创面待评估 · 点击查看详情',
                      style: AppTheme.micro.copyWith(
                          color: AppTheme.actionBlue)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 22),
          ],
        ),
      ),
    );
  }
}
