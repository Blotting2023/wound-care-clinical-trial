/// B 通道 PI 审核页（任务卡 W4.1）。
///
/// CRC 提交 B 通道纸质件后，PI 进此页核对：
///   1) 查看纸质件图像（无图显示占位）
///   2) 输入审核备注
///   3) 确认 → POST /consents/:id/review → reviewedByPi=true
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/consent_form.dart';
import '../../services/api_client.dart';
import '../../services/consent_service.dart';
import '../../widgets/app_ui.dart';

class ConsentPaperReviewScreen extends StatefulWidget {
  final ConsentForm consent;
  const ConsentPaperReviewScreen({super.key, required this.consent});

  @override
  State<ConsentPaperReviewScreen> createState() =>
      _ConsentPaperReviewScreenState();
}

class _ConsentPaperReviewScreenState extends State<ConsentPaperReviewScreen> {
  final _consent = ConsentService(apiClient: ApiClient.instance);
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    setState(() => _submitting = true);
    final result = await _consent.reviewPaperConsent(
      consentId: widget.consent.id,
      note: _noteCtrl.text.trim().isEmpty ? '（PI 已审核）' : _noteCtrl.text.trim(),
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('审核通过')));
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('审核失败：${result.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consent;
    final hasImage = c.signedPaperPath != null &&
        File(c.signedPaperPath!).existsSync();
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('PI 审核 B 通道')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fact_check_outlined,
                        size: 18, color: AppTheme.actionBlue),
                    const SizedBox(width: 6),
                    const Text('纸质件图像',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (c.reviewedByPi)
                      const TypeChip(label: '已审核', selected: true),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(c.signedPaperPath!),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.pageBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('图像不可用（仅元数据）',
                        style: AppTheme.micro),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('纸质件信息',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _info('受试者', c.patientId),
                _info('方案', c.protocolId),
                _info('ICF 版本', c.version),
                _info(
                  '签日期',
                  c.paperSignedDate != null
                      ? c.paperSignedDate!
                          .toIso8601String()
                          .substring(0, 10)
                      : '—',
                ),
                _info('见证人', c.witnessName ?? '—'),
                _info('提交人', c.signedByName ?? c.signedBy),
                _info('提交时间', c.signedAt.toIso8601String().substring(0, 19)),
                if (c.reviewNote != null && c.reviewNote!.isNotEmpty)
                  _info('审核备注', c.reviewNote!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('审核备注',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '例：纸质件与电子受试者信息一致，已现场确认',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (c.isWithdrawn)
            AppCard(
              child: Text(
                '⚠️ 该知情同意已撤回（${c.withdrawReason ?? "无原因"}）',
                style: AppTheme.body.copyWith(
                    color: AppTheme.statusPendingSign,
                    fontWeight: FontWeight.w600),
              ),
            )
          else
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting || c.reviewedByPi ? null : _review,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusLocked,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        c.reviewedByPi ? '已审核' : '确认审核通过',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 70,
                child: Text(label,
                    style: AppTheme.micro
                        .copyWith(color: AppTheme.textSecondary))),
            Expanded(
                child: Text(value,
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
