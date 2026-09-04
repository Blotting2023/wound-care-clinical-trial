import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

/// GCP W3.2 — CRF 完成声明弹窗。
///
/// PI 必签 + 6 位 PIN 二次鉴别。点击"正式声明并锁定"返回 true，
/// review 页拿到 true 后会调 confirm + PATCH /declare-crf-complete
/// 把临床字段锁死，再跳到 PIN 签名屏。
class CrfCompletionDialog extends StatefulWidget {
  const CrfCompletionDialog({super.key});

  @override
  State<CrfCompletionDialog> createState() => _CrfCompletionDialogState();
}

class _CrfCompletionDialogState extends State<CrfCompletionDialog> {
  final _pinCtrl = TextEditingController();
  bool _agreed = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_agreed) {
      setState(() => _error = '请先勾选"我已确认"声明');
      return;
    }
    if (_pinCtrl.text.length < 4) {
      setState(() => _error = 'PIN 至少 4 位');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.actionBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_outlined,
                        size: 20, color: AppTheme.actionBlue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('PI · CRF 完成声明',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.noticeBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.actionBlue.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.policy_rounded,
                            size: 18, color: AppTheme.actionBlue),
                        SizedBox(width: 6),
                        Text('GCP §58 + 21 CFR Part 11 双合规',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.actionBlue)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '完成声明意味着：CRF 所有字段已审阅、合并用药 / AE 占位已 NDA 标注、'
                      '与原始病历核对一致，对数据完整性承担最终责任。签后该评估的临床字段会锁死，'
                      '修改只能走"数据修订"流程并写审计日志。',
                      style: TextStyle(fontSize: 12, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                title: const Text(
                  '我已确认所有 CRF 字段完整、准确，并承担 GCP 数据完整性的最终责任',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
              const Text('PIN 二次鉴别（≥4 位）',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  hintText: '••••••',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.gavel_rounded, size: 18),
                      label: const Text('正式声明并锁定'),
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
