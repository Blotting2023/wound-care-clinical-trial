import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/protocol.dart';
import '../models/protocol_document.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';
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
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ProtocolDetailScreen(protocol: p),
          ));
        },
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

/// W6 — 方案详情页：方案信息 + 文档列表（Word/PDF 上传）。
class _ProtocolDetailScreen extends StatefulWidget {
  final Protocol protocol;
  const _ProtocolDetailScreen({required this.protocol});

  @override
  State<_ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<_ProtocolDetailScreen> {
  late final ProtocolService _service =
      ProtocolService(apiClient: ApiClient.instance);

  List<ProtocolDocument> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  bool get _canManage => PermissionService.instance.can(
      context.read<AuthProvider>().user, Permission.protocolManage);

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _service.listDocuments(widget.protocol.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success) {
        _docs = res.data ?? [];
      } else {
        _error = res.message;
      }
    });
  }

  /// W6 — 选文件并上传元数据（真实字节 V4 走 COS 对象存储）。
  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: false,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final ext = (file.extension ?? '').toLowerCase();
    if (!['pdf', 'doc', 'docx'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持 Word（doc/docx）或 PDF 文件')),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    final res = await _service.uploadDocument(
      protocolId: widget.protocol.id,
      fileName: file.name,
      fileExt: ext,
      fileSizeBytes: file.size,
      version: widget.protocol.version,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (res.success && res.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已上传「${file.name}」（已记入审计）')),
      );
      _loadDocs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败：${res.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final status = p.status == 'active'
        ? '进行中'
        : (p.status == 'draft' ? '草案' : '已关闭');
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: Text(p.code.isNotEmpty ? p.code : '方案详情')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.actionBlue,
              foregroundColor: Colors.white,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('上传方案'),
              onPressed: _uploading ? null : _pickAndUpload,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // ---- 方案信息卡 ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          p.name.isNotEmpty ? p.name : '(未命名方案)',
                          style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    TypeChip(label: status, selected: p.status == 'active'),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow('代号', p.code),
                _infoRow('版本', p.version),
                _infoRow('申办方', p.sponsor),
                _infoRow('试验期', p.phase),
                _infoRow('开始',
                    '${p.startDate.year}/${_pad2(p.startDate.month)}/${_pad2(p.startDate.day)}'),
                if ((p.summary ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(p.summary!, style: AppTheme.micro),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ---- 文档区 ----
          Row(
            children: [
              const Expanded(child: SectionTitle('方案文档')),
              Text('${_docs.length} 份',
                  style: AppTheme.micro
                      .copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppCard(
              child: Text('加载失败：$_error', style: AppTheme.micro),
            )
          else if (_docs.isEmpty)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.folder_open_outlined,
                      size: 40, color: AppTheme.textHint),
                  const SizedBox(height: 10),
                  Text('暂无方案文档',
                      style: AppTheme.body
                          .copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _canManage
                        ? '点击右下角「上传方案」添加 Word / PDF'
                        : '仅 PI / 管理员可上传文档',
                    style: AppTheme.micro
                        .copyWith(color: AppTheme.textHint),
                  ),
                ],
              ),
            )
          else
            ..._docs.map(_buildDocTile),
          const SizedBox(height: 12),
          // V4 提示
          Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  size: 14, color: AppTheme.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'V1 演示版仅登记文档元数据；V4 接入对象存储后支持在线预览与下载',
                  style:
                      AppTheme.micro.copyWith(color: AppTheme.textHint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: AppTheme.micro
                    .copyWith(color: AppTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: AppTheme.micro)),
        ],
      ),
    );
  }

  Widget _buildDocTile(ProtocolDocument d) {
    final isPdf = d.isPdf;
    final iconColor = isPdf ? const Color(0xFFD93025) : AppTheme.actionBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${d.fileName}」V4 接入对象存储后可在线预览')),
          );
        },
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isPdf ? 'PDF' : 'W',
                  style: AppTheme.micro.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${d.fileSizeLabel} · ${d.uploadedByName ?? d.uploadedBy} · '
                    '${d.uploadedAt.year}/${_pad2(d.uploadedAt.month)}/${_pad2(d.uploadedAt.day)}',
                    style: AppTheme.micro.copyWith(
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            TypeChip(label: 'v${d.version}', selected: false),
          ],
        ),
      ),
    );
  }

  String _pad2(int v) => v < 10 ? '0$v' : '$v';
}
