import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/app_ui.dart';

/// GCP W3.2 — CRF 三态录入页。
///
/// 合并用药 / 合并疾病 / AE 占位都必须填 ND/UN/NA 三态之一（后端 400 校验）。
/// 屏幕顶部三段独立表单，每段都是 "三态单选 + 可选原因文本"。
///
/// 返回 [_CrfTriStateResult] 给 review 页。
class ConcomitantMedScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialMeds;
  final List<Map<String, dynamic>>? initialDiseases;
  final List<Map<String, dynamic>>? initialAeRefs;

  const ConcomitantMedScreen({
    super.key,
    this.initialMeds,
    this.initialDiseases,
    this.initialAeRefs,
  });

  @override
  State<ConcomitantMedScreen> createState() => _ConcomitantMedScreenState();
}

/// 三态选项（CDISC / NIH 标准，V1 采用）。
const List<String> _kTriStates = ['ND', 'UN', 'NA'];
/// 三态可读标签。
const Map<String, String> _kTriStateLabels = {
  'ND': '不知道（Not Done）',
  'UN': '未做（Unknown）',
  'NA': '不适用（Not Applicable）',
};

class _ConcomitantMedScreenState extends State<ConcomitantMedScreen> {
  String? _medsState;
  String? _medsNote;
  String? _diseasesState;
  String? _diseasesNote;
  String? _aeState;
  String? _aeNote;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialMeds, (s, n) {
      _medsState = s;
      _medsNote = n;
    });
    _hydrate(widget.initialDiseases, (s, n) {
      _diseasesState = s;
      _diseasesNote = n;
    });
    _hydrate(widget.initialAeRefs, (s, n) {
      _aeState = s;
      _aeNote = n;
    });
  }

  void _hydrate(
    List<Map<String, dynamic>>? list,
    void Function(String? triState, String? note) apply,
  ) {
    if (list == null || list.isEmpty) return;
    for (final item in list) {
      final ts = item['triState'];
      if (ts is String && _kTriStates.contains(ts)) {
        apply(ts, item['note'] as String?);
        return;
      }
    }
  }

  Future<void> _save() async {
    if (_medsState == null || _diseasesState == null || _aeState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('三个 CRF 字段都必须填 ND/UN/NA 三态之一'),
      ));
      return;
    }
    final meds = <Map<String, dynamic>>[
      {'triState': _medsState, 'note': _medsNote ?? ''},
    ];
    final diseases = <Map<String, dynamic>>[
      {'triState': _diseasesState, 'note': _diseasesNote ?? ''},
    ];
    final aeRefs = <Map<String, dynamic>>[
      {'triState': _aeState, 'note': _aeNote ?? ''},
    ];
    Navigator.pop(
      context,
      CrfTriStateResult(
        medications: meds,
        diseases: diseases,
        aeRefs: aeRefs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('CRF 三态录入'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const StepIndicator(
              step: 3, total: 4, label: '合并用药 / 合并疾病 / AE 三态'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.noticeBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppTheme.actionBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CRF 字段三态约束（GCP §62）：不允许 NULL；必须显式标注 ND/UN/NA。\n'
                    '缺字段提交后端会返回 400 · "CRF 字段 X 必须包含 ND/UN/NA 三态"',
                    style: AppTheme.micro
                        .copyWith(color: AppTheme.actionBlue, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTriStateCard(
            title: '合并用药',
            desc: '本次评估时患者服用的所有非试验用药（如降压药、降糖药）。',
            state: _medsState,
            note: _medsNote,
            onState: (v) => setState(() => _medsState = v),
            onNote: (v) => setState(() => _medsNote = v),
          ),
          const SizedBox(height: 12),
          _buildTriStateCard(
            title: '合并疾病',
            desc: '既往慢性疾病（如高血压、糖尿病、冠心病）。',
            state: _diseasesState,
            note: _diseasesNote,
            onState: (v) => setState(() => _diseasesState = v),
            onNote: (v) => setState(() => _diseasesNote = v),
          ),
          const SizedBox(height: 12),
          _buildTriStateCard(
            title: 'AE 占位（不良事件）',
            desc: '本次评估期间是否出现不良事件；V2 接 SAE 流程。',
            state: _aeState,
            note: _aeNote,
            onState: (v) => setState(() => _aeState = v),
            onNote: (v) => setState(() => _aeNote = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTriStateCard({
    required String title,
    required String desc,
    required String? state,
    required String? note,
    required void Function(String?) onState,
    required void Function(String?) onNote,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, style: AppTheme.micro),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _kTriStates)
                ChoiceChip(
                  label: Text(s),
                  selected: state == s,
                  onSelected: (_) => onState(s),
                  selectedColor: AppTheme.actionBlue.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: state == s
                        ? AppTheme.actionBlue
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: note)
              ..selection = TextSelection.collapsed(offset: (note ?? '').length),
            maxLines: 2,
            onChanged: onNote,
            decoration: const InputDecoration(
              hintText: '备注（可选 · 三态原因 / 具体用药）',
            ),
          ),
          if (state != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppTheme.statusLocked),
                const SizedBox(width: 4),
                Text('已选 ${_kTriStateLabels[state]}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.statusLocked,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ConcomitantMedScreen 推回给 review 页的结果（公开，方便 review 页用）。
class CrfTriStateResult {
  final List<Map<String, dynamic>> medications;
  final List<Map<String, dynamic>> diseases;
  final List<Map<String, dynamic>> aeRefs;
  const CrfTriStateResult({
    required this.medications,
    required this.diseases,
    required this.aeRefs,
  });
}
