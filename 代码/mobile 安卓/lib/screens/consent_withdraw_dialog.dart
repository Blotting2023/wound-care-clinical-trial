/// 撤回知情同意书（任务卡 W4.1）。
///
/// 弹窗式：输入 reason → 调 `/consents/:id/withdraw`。
library;

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/consent_form.dart';
import '../../services/api_client.dart';
import '../../services/consent_service.dart';

class ConsentWithdrawDialog extends StatefulWidget {
  final ConsentForm consent;
  const ConsentWithdrawDialog({super.key, required this.consent});

  static Future<ConsentForm?> show(BuildContext context, ConsentForm c) {
    return showDialog<ConsentForm>(
      context: context,
      builder: (_) => ConsentWithdrawDialog(consent: c),
    );
  }

  @override
  State<ConsentWithdrawDialog> createState() => _ConsentWithdrawDialogState();
}

class _ConsentWithdrawDialogState extends State<ConsentWithdrawDialog> {
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  static const _presets = [
    '受试者主动撤回',
    '严重不良事件（SAE）',
    '违反入排标准',
    '其他（请在备注说明）',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写撤回原因')));
      return;
    }
    setState(() => _submitting = true);
    final result = await ConsentService(apiClient: ApiClient.instance)
        .withdraw(consentId: widget.consent.id, reason: reason);
    setState(() => _submitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('撤回失败：${result.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('撤回知情同意'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '撤回对象：${widget.consent.patientId}（${widget.consent.mode.displayName}）',
              style: AppTheme.caption,
            ),
            const SizedBox(height: 8),
            Text(
              '撤回后此 consent 视为失效，相关评估记录会标记待复核。',
              style: AppTheme.micro.copyWith(color: AppTheme.statusPendingSign),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ActionChip(
                    label: Text(p, style: AppTheme.micro),
                    onPressed: () => setState(() => _reasonCtrl.text = p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '撤回原因',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认撤回',
                  style: TextStyle(color: AppTheme.statusPendingSign)),
        ),
      ],
    );
  }
}
