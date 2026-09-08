import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/center.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';
import '../services/trial_service.dart';
import '../services/api_client.dart';
import '../widgets/app_ui.dart';

/// GCP W2 · 研究中心管理页.
class CenterManageScreen extends StatefulWidget {
  const CenterManageScreen({super.key});

  @override
  State<CenterManageScreen> createState() => _CenterManageScreenState();
}

class _CenterManageScreenState extends State<CenterManageScreen> {
  late final CenterService _service =
      CenterService(apiClient: ApiClient.instance);

  List<ResearchCenter> _items = [];
  bool _loading = true;
  String? _error;

  bool get _canManage => PermissionService.instance
      .can(context.read<AuthProvider>().user, Permission.centerManage);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.listCenters();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _items = res.data!;
        _error = null;
      } else {
        _error = res.message;
      }
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<ResearchCenter>(
      MaterialPageRoute(builder: (_) => const _CenterCreateScreen()),
    );
    if (created != null && mounted) {
      setState(() => _items = [..._items, created]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加中心 ${created.code}')),
      );
    }
  }

  /// W6 — 编辑负责人 / 联系方式（PI/Admin）。
  Future<void> _openEdit(ResearchCenter c) async {
    final piCtrl = TextEditingController(text: c.leadPiName ?? '');
    final contactCtrl = TextEditingController(text: c.piContact ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑 ${c.name}', style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: piCtrl,
              decoration: const InputDecoration(
                labelText: '负责人（主要研究者）',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(
                labelText: '联系方式（电话 / 邮箱）',
                hintText: '139-xxxx-xxxx · name@hospital.cn',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.actionBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final contact = contactCtrl.text.trim();
    final res = await _service.updateCenter(
      c.id,
      leadPiName: piCtrl.text.trim(),
      piContact: contact.isEmpty ? null : contact,
    );
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _items = [
          for (final it in _items)
            if (it.id == c.id) res.data! else it,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('中心信息已保存（已记入审计）')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：${res.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('研究中心')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.actionBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加中心'),
        onPressed: _openCreate,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _CenterCard(
                          c: _items[i],
                          canManage: _canManage,
                          onEdit: () => _openEdit(_items[i]),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.statusPendingSign),
              const SizedBox(height: 12),
              Text(_error ?? '加载失败',
                  style: AppTheme.body, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.actionBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(42),
              ),
              child: const Icon(Icons.local_hospital_outlined,
                  size: 42, color: AppTheme.actionBlue),
            ),
            const SizedBox(height: 18),
            Text('尚未登记研究中心', style: AppTheme.body),
            const SizedBox(height: 6),
            Text('点击右下角「添加中心」',
                style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _CenterCard extends StatelessWidget {
  final ResearchCenter c;
  final bool canManage;
  final VoidCallback? onEdit;
  const _CenterCard({required this.c, this.canManage = false, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.name,
                      style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                TypeChip(
                  label: c.irbApprovalDate == null ? '待 IRB' : 'IRB 已批',
                  selected: c.irbApprovalDate != null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${c.code} · ${c.department}', style: AppTheme.micro),
            if ((c.address ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 14, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(c.address!, style: AppTheme.micro),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    c.leadPiName == null || c.leadPiName!.isEmpty
                        ? 'PI 待指派'
                        : ('PI ${c.leadPiName}'),
                    style: AppTheme.micro
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                ),
                if (canManage && onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined,
                              size: 13, color: AppTheme.actionBlue),
                          const SizedBox(width: 2),
                          Text('编辑',
                              style: AppTheme.micro.copyWith(
                                  color: AppTheme.actionBlue)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // W6 — 负责人联系方式
            if ((c.piContact ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.call_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(c.piContact!,
                        style: AppTheme.micro
                            .copyWith(color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ] else if (c.leadPiName != null &&
                c.leadPiName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('联系方式待补录',
                  style: AppTheme.micro.copyWith(
                      color: AppTheme.textHint, fontStyle: FontStyle.italic)),
            ],
            if ((c.irbNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('IRB ${c.irbNumber}', style: AppTheme.micro),
            ],
          ],
        ),
      ),
    );
  }
}

/// 中心添加页.
class _CenterCreateScreen extends StatefulWidget {
  const _CenterCreateScreen();
  @override
  State<_CenterCreateScreen> createState() => _CenterCreateScreenState();
}

class _CenterCreateScreenState extends State<_CenterCreateScreen> {
  late final CenterService _service =
      CenterService(apiClient: ApiClient.instance);
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _dept = TextEditingController();
  final _address = TextEditingController();
  final _irb = TextEditingController();
  final _pi = TextEditingController();
  final _piContact = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _dept.dispose();
    _address.dispose();
    _irb.dispose();
    _pi.dispose();
    _piContact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final res = await _service.createCenter(
      code: _code.text.trim(),
      name: _name.text.trim(),
      department: _dept.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      irbNumber: _irb.text.trim().isEmpty ? null : _irb.text.trim(),
      leadPiName: _pi.text.trim().isEmpty ? null : _pi.text.trim(),
      piContact:
          _piContact.text.trim().isEmpty ? null : _piContact.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success && res.data != null) {
      Navigator.pop(context, res.data);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('添加失败：${res.message}')),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? '$label 必填' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        style: AppTheme.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('添加研究中心')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _field(_code, '中心编号', 'SD-HOSP-003', required: true),
            _field(_name, '医院名称', '例：山东省立医院', required: true),
            _field(_dept, '承担科室', '例：烧伤整形科', required: true),
            _field(_address, '医院地址', '可选'),
            _field(_irb, 'IRB 编号', '选填'),
            _field(_pi, '主要研究者', '选填'),
            _field(_piContact, '负责人联系方式', '电话 / 邮箱，选填'),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppTheme.actionBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
