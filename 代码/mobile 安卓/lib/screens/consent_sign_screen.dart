/// A 通道 eConsent 签名页（任务卡 W4.1）。
///
/// 流程：
/// 1) 展示内置 ICF 示例（V1 demo 用占位卡代替真 PDF）
/// 2) "我已阅读并同意"勾选
/// 3) 手写签名画板（保存笔迹坐标 JSON）
/// 4) 提交 → POST /consents (mode=E_CONSENT)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/consent_form.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/consent_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/signature_pad.dart';

class ConsentSignScreen extends StatefulWidget {
  final String patientId;
  final String protocolId;
  final String? centerId;
  const ConsentSignScreen({
    super.key,
    required this.patientId,
    required this.protocolId,
    this.centerId,
  });

  @override
  State<ConsentSignScreen> createState() => _ConsentSignScreenState();
}

class _ConsentSignScreenState extends State<ConsentSignScreen> {
  final _consent = ConsentService(apiClient: ApiClient.instance);
  bool _agreed = false;
  final _signatureKey = GlobalKey<SignaturePadState>();
  final _versionCtrl = TextEditingController(text: 'V1.0');
  bool _submitting = false;

  @override
  void dispose() {
    _versionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreed) {
      _toast('请先勾选"我已阅读并同意"');
      return;
    }
    final pad = _signatureKey.currentState;
    if (pad == null || pad.isEmpty) {
      _toast('请先签名');
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _toast('未登录');
      return;
    }
    setState(() => _submitting = true);
    final box = _signatureKey.currentContext!.findRenderObject() as RenderBox;
    final size = box.size;
    final strokeJson = pad.toJsonString(size);
    final result = await _consent.create(
      patientId: widget.patientId,
      protocolId: widget.protocolId,
      centerId: widget.centerId,
      version: _versionCtrl.text.trim().isEmpty
          ? '1.0'
          : _versionCtrl.text.trim(),
      mode: ConsentMode.E_CONSENT,
      signedBy: user.id,
      signedByName: user.displayName,
      pdfPath: 'demo://icf-${_versionCtrl.text.trim()}.pdf',
      signaturePath: 'demo://signature-${DateTime.now().millisecondsSinceEpoch}.png',
      signatureStrokeJson: strokeJson,
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (result.success) {
      _toast('签署成功');
      Navigator.pop(context, result.data);
    } else {
      _toast('签署失败：${result.message}');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('电子知情同意（A 通道）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.description_outlined,
                        size: 18, color: AppTheme.actionBlue),
                    SizedBox(width: 6),
                    Text('知情同意书（ICF）',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '【示例 ICF · V1 demo】\n'
                  '本知情同意书描述本研究的目的、流程、可能的风险与获益、'
                  '您的权利以及保密措施。V1 演示阶段为占位文本，'
                  '生产环境应替换为 IRB 批准的真实 ICF PDF 文件。',
                  style: AppTheme.micro.copyWith(height: 1.6),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('ICF 版本：', style: AppTheme.caption),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _versionCtrl,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        style: AppTheme.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请在下方签名',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SignaturePad(
                  key: _signatureKey,
                  height: 200,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _signatureKey.currentState?.clear(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('清除'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '我已阅读并理解本知情同意书的所有内容，自愿参与本研究。',
                    style: AppTheme.caption.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionBlue,
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
                  : const Text('确认签署',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '签署后 21 CFR Part 11 留痕：设备指纹 + IP + 时间戳',
              style: AppTheme.micro,
            ),
          ),
        ],
      ),
    );
  }
}
