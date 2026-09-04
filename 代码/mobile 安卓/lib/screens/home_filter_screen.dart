import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../widgets/app_ui.dart';

enum HomeFilter { pendingAssess, pendingSign, todayFollowUp }

extension _HomeFilterExt on HomeFilter {
  String get title {
    switch (this) {
      case HomeFilter.pendingAssess:
        return '待评估记录';
      case HomeFilter.pendingSign:
        return '待签名记录';
      case HomeFilter.todayFollowUp:
        return '今日随访';
    }
  }

  String get emptyHint {
    switch (this) {
      case HomeFilter.pendingAssess:
        return '暂无待评估患者';
      case HomeFilter.pendingSign:
        return '暂无待签名患者';
      case HomeFilter.todayFollowUp:
        return '今日暂无随访记录';
    }
  }
}

/// 首页概览点击后进入的筛选列表：展示符合该统计项的患者。
class HomeFilterScreen extends StatelessWidget {
  final HomeFilter filter;
  final List<Assessment> allAssessments;
  final List<Patient> patients;

  const HomeFilterScreen({
    super.key,
    required this.filter,
    required this.allAssessments,
    required this.patients,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = allAssessments.where((a) {
      switch (filter) {
        case HomeFilter.pendingAssess:
          return a.status == AssessmentStatus.draft;
        case HomeFilter.pendingSign:
          return a.status == AssessmentStatus.pendingSignature;
        case HomeFilter.todayFollowUp:
          final d = a.createdAt;
          final cd = DateTime(d.year, d.month, d.day);
          return cd.isAtSameMomentAs(today);
      }
    }).toList();

    // 按患者分组，保留每个患者的最新一条。
    final byPatient = <String, Assessment>{};
    for (final a in filtered) {
      byPatient[a.patientId] = a;
    }

    final rows = byPatient.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final patientMap = {for (final p in patients) p.id: p};

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(filter.title),
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(filter.emptyHint, style: AppTheme.caption),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final a in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () {
                        final p = patientMap[a.patientId];
                        if (p != null) {
                          Navigator.pushNamed(context, '/patient-detail',
                              arguments: p);
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientMap[a.patientId]?.name ?? a.patientId,
                                  style: AppTheme.body
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '病案号 ${patientMap[a.patientId]?.medicalRecordNo ?? '—'}',
                                  style: AppTheme.micro,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_fmtDate(a.createdAt)} · ${_statusLabel(a.status)}',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                          _statusChip(a.status),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _statusChip(AssessmentStatus status) {
    switch (status) {
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

  String _statusLabel(AssessmentStatus status) {
    switch (status) {
      case AssessmentStatus.draft:
        return '待评估';
      case AssessmentStatus.pendingSignature:
        return '待签名';
      case AssessmentStatus.locked:
        return '已锁定';
      case AssessmentStatus.archived:
        return '已归档';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
