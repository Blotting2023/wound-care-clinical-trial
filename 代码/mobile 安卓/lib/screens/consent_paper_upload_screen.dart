/// B 通道 — 纸质知情同意书拍照存档（任务卡 W4.1）。
///
/// 流程：
/// 1) 拍照 / 从相册导入纸质件签字页图像
/// 2) 录入 ICF 版本 + 见证人
/// 3) 录入签日期（PI 手动录入，不依赖 EXIF 因为纸质件是后期拍照）
/// 4) 提交 → POST /consents (mode=PAPER_PHOTO, reviewedByPi=false)
///
/// 提交后由 PI 在 `ConsentPaperReviewScreen` 复核（reviewedByPi=true）。
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/consent_form.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/consent_service.dart';
import '../../utils/photo_time.dart';
import '../../widgets/app_ui.dart';

class ConsentPaperUploadScreen extends StatefulWidget {
  final String patientId;
  final String protocolId;
  final String? centerId;
  const ConsentPaperUploadScreen({
    super.key,
    required this.patientId,
    required this.protocolId,
    this.centerId,
  });

  @override
  State<ConsentPaperUploadScreen> createState() =>
      _ConsentPaperUploadScreenState();
}

class _ConsentPaperUploadScreenState extends State<ConsentPaperUploadScreen> {
  final _consent = ConsentService(apiClient: ApiClient.instance);
  final _picker = ImagePicker();
  String? _paperPath;
  DateTime? _paperSignedDate;
  final _versionCtrl = TextEditingController(text: 'V1.0');
  final _witnessCtrl = TextEditingController();
  bool _submitting = false;
  String _photoTimeSource = 'now';

  @override
  void dispose() {
    _versionCtrl.dispose();
    _witnessCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;
    final dir = await getTemporaryDirectory();
    final ext = picked.name.contains('.')
        ? picked.name.substring(picked.name.lastIndexOf('.'))
        : '.jpg';
    final dest =
        '${dir.path}/consent_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(picked.path).copy(dest);

    // 拍照时（相机）→ 现在；导入时（相册）→ EXIF 拍摄时间
    String src;
    DateTime recordedAt;
    if (source == ImageSource.camera) {
      src = 'capture_time';
      recordedAt = DateTime.now();
    } else {
      final t = await readPhotoTakenAt(dest);
      src = t?.source ?? 'file_mtime';
      recordedAt = t?.takenAt ?? DateTime.now();
    }
    if (!mounted) return;
    setState(() {
      _paperPath = dest;
      _paperSignedDate = recordedAt;
      _photoTimeSource = src;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paperSignedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _paperSignedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          (_paperSignedDate ?? now).hour,
          (_paperSignedDate ?? now).minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_paperPath == null) {
      _toast('请先拍摄或导入纸质件');
      return;
    }
    if (_paperSignedDate == null) {
      _toast('请录入纸质件签署日期');
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _toast('未登录');
      return;
    }
    setState(() => _submitting = true);
    final result = await _consent.create(
      patientId: widget.patientId,
      protocolId: widget.protocolId,
      centerId: widget.centerId,
      version: _versionCtrl.text.trim().isEmpty
          ? '1.0'
          : _versionCtrl.text.trim(),
      mode: ConsentMode.PAPER_PHOTO,
      signedBy: user.id,
      signedByName: user.displayName,
      signedPaperPath: _paperPath,
      paperSignedDate: _paperSignedDate,
      witnessName: _witnessCtrl.text.trim().isEmpty
          ? null
          : _witnessCtrl.text.trim(),
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (result.success) {
      _toast('已提交，等待 PI 审核');
      Navigator.pop(context, result.data);
    } else {
      _toast('提交失败：${result.message}');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('纸质知情同意（B 通道）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.camera_alt_outlined,
                        size: 18, color: AppTheme.actionBlue),
                    SizedBox(width: 6),
                    Text('拍摄 / 导入纸质签字页',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_paperPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_paperPath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('记录时间来源：$_photoTimeSource',
                      style: AppTheme.micro),
                ] else
                  Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.pageBackground,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
                    ),
                    child: const Text('尚未选择图像',
                        style: AppTheme.micro),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('拍照'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: const Text('相册'),
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
                const Text('纸质件信息',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ICF 版本',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _witnessCtrl,
                  decoration: const InputDecoration(
                    labelText: '见证人（可选）',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '纸质件签署日期',
                      isDense: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      _paperSignedDate == null
                          ? '点击选择'
                          : '${_paperSignedDate!.year}-${_paperSignedDate!.month.toString().padLeft(2, '0')}-${_paperSignedDate!.day.toString().padLeft(2, '0')}',
                      style: AppTheme.body,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'V1 demo 说明：默认从 EXIF/拍照时间自动填，'
                  'PI 需在此基础上人工核对签署日期（合规留痕）。',
                  style: AppTheme.micro.copyWith(color: AppTheme.textSecondary),
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
                  : const Text('提交并送 PI 审核',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
