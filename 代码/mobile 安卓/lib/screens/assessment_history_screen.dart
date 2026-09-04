import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/assessment.dart';
import '../models/enums.dart';
import '../models/wound.dart';
import '../providers/assessment_provider.dart';
import '../services/api_client.dart';
import '../services/wound_service.dart';

/// Assessment timeline for a single wound.
/// Shows past assessments, allows starting a new one and signing pending ones.
class AssessmentHistoryScreen extends StatefulWidget {
  final String woundId;
  const AssessmentHistoryScreen({super.key, required this.woundId});

  @override
  State<AssessmentHistoryScreen> createState() => _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  final WoundService _woundService = WoundService(apiClient: ApiClient.instance);
  Wound? _wound;
  String? _woundError;

  @override
  void initState() {
    super.initState();
    _loadWound();
    context.read<AssessmentProvider>().loadHistory(widget.woundId);
  }

  Future<void> _loadWound() async {
    final result = await _woundService.getWound(widget.woundId);
    if (!mounted) return;
    setState(() {
      _wound = result.success ? result.data : null;
      _woundError = result.success ? null : result.message;
    });
  }

  Future<void> _reload() async {
    await Future.wait([
      _loadWound(),
      context.read<AssessmentProvider>().loadHistory(widget.woundId),
    ]);
  }

  void _startNewAssessment() {
    final wound = _wound;
    if (wound == null) return;
    Navigator.pushNamed(context, '/capture', arguments: {
      'patientId': wound.patientId,
      'woundId': wound.id,
      'patientName': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssessmentProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_wound?.displayLabel ?? '评估历史')),
      body: _buildBody(provider),
      floatingActionButton: _wound == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.camera_alt),
              label: const Text('新建评估'),
              onPressed: _startNewAssessment,
            ),
    );
  }

  Widget _buildBody(AssessmentProvider provider) {
    if (_woundError != null && _wound == null) {
      return Center(child: Text('加载创面失败: $_woundError'));
    }
    if (provider.isLoading && provider.history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = provider.history;
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('暂无评估记录，点击右下角开始第一次评估')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildCard(context, list[i]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Assessment a) {
    final area = a.finalAreaCm2 ?? a.aiAreaCm2;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('${_fmtDate(a.createdAt)} · ${_statusLabel(a.status)}'),
        subtitle: Text(area != null
            ? '面积: ${area.toStringAsFixed(1)} cm²'
            : '未完成测量'),
        trailing: a.status == AssessmentStatus.pendingSignature
            ? ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/sign', arguments: a.id),
                child: const Text('签名'),
              )
            : null,
      ),
    );
  }

  String _statusLabel(AssessmentStatus status) {
    switch (status) {
      case AssessmentStatus.draft:
        return '草稿';
      case AssessmentStatus.pendingSignature:
        return '待签名';
      case AssessmentStatus.locked:
        return '已锁定';
      case AssessmentStatus.archived:
        return '已归档';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
