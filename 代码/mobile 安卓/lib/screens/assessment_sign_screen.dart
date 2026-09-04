import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/assessment_provider.dart';
import '../widgets/app_ui.dart';

/// 电子签名锁定（设计稿 06，21 CFR Part 11）：
/// 评估汇总 + 合规声明 + 6 位 PIN + 签名人信息 + 锁定按钮，单屏紧凑完成。
/// 签名成功后直接返回患者详情页。
class AssessmentSignScreen extends StatefulWidget {
  final String assessmentId;
  const AssessmentSignScreen({super.key, required this.assessmentId});

  @override
  State<AssessmentSignScreen> createState() => _AssessmentSignScreenState();
}

class _AssessmentSignScreenState extends State<AssessmentSignScreen> {
  final _pinCtrl = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _signAndLock() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('签名 PIN 必须是 6 位数字')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await context.read<AssessmentProvider>().lock(
            widget.assessmentId,
            pin,
            '本人确认该评估记录准确完整',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评估已锁定 ✓')),
      );
      // 回退到患者详情页（栈中不存在时退回首屏）。
      Navigator.popUntil(context, ModalRoute.withName('/patient-detail'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('锁定失败: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final assessment = context.watch<AssessmentProvider>().current;
    final area = assessment?.finalAreaCm2 ?? assessment?.aiAreaCm2;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('电子签名')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 评估汇总 + 签名人（合并一卡，紧凑）
              AppCard(
                child: Column(
                  children: [
                    _row('患者', assessment?.patientId ?? '—'),
                    _row('创面', assessment?.woundId ?? '—'),
                    _row('评分',
                        'VSS${assessment?.vssTotal ?? '—'} · NRS${assessment?.nrsPainScore ?? '—'}'),
                    _row('面积', area != null ? '${area.toStringAsFixed(1)} cm²' : '—'),
                    const Divider(height: 14, color: AppTheme.cardBorder),
                    _row('签名人', '李慧 · 副主任医师'),
                    _row('工号', 'LI-0284'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 合规声明（单行紧凑）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.noticeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 15, color: AppTheme.actionBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '签名后记录锁定不可修改，操作全程留痕（GCP / 21 CFR Part 11）',
                        style: AppTheme.micro.copyWith(
                            color: AppTheme.actionBlue, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 签名 PIN
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('签名 PIN',
                        style:
                            TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: TextField(
                        controller: _pinCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '6 位数字',
                          hintStyle: const TextStyle(
                              fontSize: 15, letterSpacing: 1),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppTheme.cardBorder),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('演示模式下任意 6 位数字有效 · V1 使用 PIN 签名',
                        style: AppTheme.micro),
                  ],
                ),
              ),

              const Spacer(),

              // 底部操作（紧凑：主按钮 + 次级文字按钮）
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _signAndLock,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_rounded, size: 20),
                label: const Text('确认签名并锁定'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('保存草稿，稍后签名'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label, style: AppTheme.micro)),
            Expanded(
                child: Text(value,
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w500))),
          ],
        ),
      );

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }
}
