import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/protocol.dart';
import '../services/trial_service.dart';
import '../services/api_client.dart';
import '../widgets/app_ui.dart';

/// GCP W2 · 试验方案管理页 — 列表 + 新建.
class ProtocolManageScreen extends StatefulWidget {
  const ProtocolManageScreen({super.key});

  @override
  State<ProtocolManageScreen> createState() => _ProtocolManageScreenState();
}

class _ProtocolManageScreenState extends State<ProtocolManageScreen> {
  late final ProtocolService _service =
      ProtocolService(apiClient: ApiClient.instance);

  List<Protocol> _items = [];
  bool _loading = true;
  String? _error;

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
    final res = await _service.listProtocols();
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
    final created = await Navigator.of(context).push<Protocol>(
      MaterialPageRoute(builder: (_) => const _ProtocolCreateScreen()),
    );
    if (created != null && mounted) {
      setState(() => _items = [..._items, created]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已新建方案 ${created.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('试验方案')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.actionBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建方案'),
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
                        itemBuilder: (_, i) =>
                            _ProtocolCard(p: _items[i], service: _service),
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.statusPendingSign),
            const SizedBox(height: 12),
            Text(_error ?? '加载失败', style: AppTheme.body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
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
            child: const Icon(Icons.assignment_outlined,
                size: 42, color: AppTheme.actionBlue),
          ),
          const SizedBox(height: 18),
          Text('暂无试验方案', style: AppTheme.body),
          const SizedBox(height: 6),
          Text('点击右下角「新建方案」开始',
              style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  final Protocol p;
  final ProtocolService service;
  const _ProtocolCard({required this.p, required this.service});

  @override
  Widget build(BuildContext context) {
    final status = p.status == 'active' ? '进行中' : (p.status == 'draft' ? '草案' : '已关闭');
    final c = p.status == 'active'
        ? AppTheme.actionBlue
        : (p.status == 'closed' ? AppTheme.textHint : AppTheme.statusPendingSign);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.name.isNotEmpty ? p.name : '(未命名方案)',
                      style: AppTheme.body
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                TypeChip(label: status, selected: p.status == 'active'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('代号', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Text(p.code, style: AppTheme.micro),
                const SizedBox(width: 16),
                Text('版本', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Text(p.version, style: AppTheme.micro),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('申办方', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Expanded(child: Text(p.sponsor, style: AppTheme.micro)),
              ],
            ),
            if ((p.summary ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.summary!,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.micro),
            ],
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: AppTheme.cardBorder,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 14, color: c),
                const SizedBox(width: 4),
                Text('试验期 ${p.phase}', style: AppTheme.micro.copyWith(color: c)),
                const Spacer(),
                Text('起 ${p.startDate.year}/${_pad(p.startDate.month)}',
                    style: AppTheme.micro),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int v) => v < 10 ? '0$v' : '$v';
}

/// 简洁的新建方案页 — 在 demo 中用最小必填字段完成提交流程.
class _ProtocolCreateScreen extends StatefulWidget {
  const _ProtocolCreateScreen();
  @override
  State<_ProtocolCreateScreen> createState() => _ProtocolCreateScreenState();
}

class _ProtocolCreateScreenState extends State<_ProtocolCreateScreen> {
  late final ProtocolService _service =
      ProtocolService(apiClient: ApiClient.instance);

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController(text: 'WOUND-2026-B');
  final _name = TextEditingController(text: '示范 RCT 方案');
  final _sponsor = TextEditingController(text: '山东笃行临床研究院');
  final _phase = TextEditingController(text: 'pilot');
  final _summary = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _sponsor.dispose();
    _phase.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final res = await _service.createProtocol(
      code: _code.text.trim(),
      name: _name.text.trim(),
      version: '1.0',
      sponsor: _sponsor.text.trim(),
      phase: _phase.text.trim(),
      startDate: DateTime.now(),
      summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success && res.data != null) {
      Navigator.pop(context, res.data);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('新建失败：${res.message}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('新建试验方案')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const SectionTitle('方案编号（不可重复）'),
            TextFormField(
              controller: _code,
              validator: (v) => (v ?? '').trim().isEmpty ? '代号必填' : null,
              decoration: const InputDecoration(
                hintText: 'WOUND-2026-B',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            const SectionTitle('方案名称'),
            TextFormField(
              controller: _name,
              validator: (v) => (v ?? '').trim().isEmpty ? '名称必填' : null,
              decoration: const InputDecoration(
                hintText: '示范 RCT 方案',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            const SectionTitle('申办方'),
            TextFormField(
              controller: _sponsor,
              validator: (v) => (v ?? '').trim().isEmpty ? '申办方必填' : null,
              decoration: const InputDecoration(
                hintText: '山东笃行临床研究院',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            const SectionTitle('试验期'),
            TextFormField(
              controller: _phase,
              validator: (v) => (v ?? '').trim().isEmpty ? '试验期必填' : null,
              decoration: const InputDecoration(
                hintText: 'pilot / pivotal / post-market',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            const SectionTitle('摘要（可选）'),
            TextFormField(
              controller: _summary,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '主要终点、入组规模、随访周期…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: AppTheme.body,
            ),
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
                  : const Text('创建方案'),
            ),
          ],
        ),
      ),
    );
  }
}
