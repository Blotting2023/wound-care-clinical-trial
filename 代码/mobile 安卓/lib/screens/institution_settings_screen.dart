/// 机构设置（任务卡 W4.1）— Admin 专属，按中心切换 eConsent 接受态度。
///
/// V1 demo 阶段不持久化到云端（demo 后端内存），生产应走 PUT /centers/:id/consent-mode
/// 并写 AuditLog CONFIG_CHANGE（已实现）。
library;

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/consent_form.dart';
import '../../services/api_client.dart';
import '../../services/consent_service.dart';
import '../../widgets/app_ui.dart';

class InstitutionSettingsScreen extends StatefulWidget {
  const InstitutionSettingsScreen({super.key});

  @override
  State<InstitutionSettingsScreen> createState() =>
      _InstitutionSettingsScreenState();
}

class _InstitutionSettingsScreenState extends State<InstitutionSettingsScreen> {
  final _service = ConsentService(apiClient: ApiClient.instance);
  List<ConsentModeCenterInfo> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _service.listCentersWithMode();
    if (!mounted) return;
    setState(() {
      _items = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _switch(ConsentModeCenterInfo c, ConsentMode newMode) async {
    if (c.mode == newMode) return;
    // 二次确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换知情同意通道'),
        content: Text(
          '${c.name}（${c.code}）\n\n'
          '当前：${c.mode.displayName}\n'
          '切换为：${newMode.displayName}\n\n'
          '切换写 AuditLog（CONFIG_CHANGE），'
          '老胡请确认这是有意操作（避免误触）。',
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认切换',
                style: TextStyle(color: AppTheme.actionBlue)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.setCenterConsentMode(
      centerId: c.id,
      mode: newMode,
    );
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${c.name} → ${newMode.shortName}')));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('切换失败：${result.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('机构设置（Admin）')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.business_rounded,
                          size: 18, color: AppTheme.actionBlue),
                      SizedBox(width: 6),
                      Text('eConsent 通道设置',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '老胡所在医院默认 B 通道（纸质件拍照）。'
                    '若某中心伦理接受 eConsent，可切 A 通道。'
                    '同一方案在不同中心可走不同通道。',
                    style: AppTheme.micro.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final c in _items) ...[
                _CenterCard(
                  info: c,
                  onSwitch: (m) => _switch(c, m),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.menu_book_rounded,
                          size: 18, color: AppTheme.statusLocked),
                      SizedBox(width: 6),
                      Text('通道差异速查',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _channelDiffRow(
                    'A 通道',
                    ConsentMode.E_CONSENT,
                    'ICF PDF + 手写签名画板 + 笔迹坐标 JSON；无需 PI 复核。',
                  ),
                  const SizedBox(height: 6),
                  _channelDiffRow(
                    'B 通道',
                    ConsentMode.PAPER_PHOTO,
                    '纸质件拍照 + PI 录入签日期 + 见证人 + PI 审核通过后生效。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelDiffRow(
      String label, ConsentMode mode, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: mode == ConsentMode.E_CONSENT
                ? AppTheme.actionBlue.withValues(alpha: 0.1)
                : AppTheme.statusLocked.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mode == ConsentMode.E_CONSENT
                    ? AppTheme.actionBlue
                    : AppTheme.statusLocked,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(desc, style: AppTheme.micro)),
      ],
    );
  }
}

class _CenterCard extends StatelessWidget {
  final ConsentModeCenterInfo info;
  final ValueChanged<ConsentMode> onSwitch;
  const _CenterCard({required this.info, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded,
                  size: 20, color: AppTheme.actionBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(info.code, style: AppTheme.micro),
                  ],
                ),
              ),
              TypeChip(
                label: info.mode.shortName,
                selected: info.mode == ConsentMode.E_CONSENT,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ConsentMode>(
            segments: const [
              ButtonSegment(
                value: ConsentMode.E_CONSENT,
                label: Text('A 通道'),
                icon: Icon(Icons.tablet_mac_rounded, size: 16),
              ),
              ButtonSegment(
                value: ConsentMode.PAPER_PHOTO,
                label: Text('B 通道'),
                icon: Icon(Icons.camera_alt_outlined, size: 16),
              ),
            ],
            selected: {info.mode},
            onSelectionChanged: (s) => onSwitch(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (info.modeSetAt != null) ...[
            const SizedBox(height: 6),
            Text(
              '上次切换：${info.modeSetAt!.toIso8601String().substring(0, 16)} · ${info.modeSetBy ?? "—"}',
              style: AppTheme.micro,
            ),
          ],
        ],
      ),
    );
  }
}
