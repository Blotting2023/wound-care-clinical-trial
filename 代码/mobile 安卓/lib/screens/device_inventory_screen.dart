import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/investigational_device.dart';
import '../services/device_service.dart';
import '../services/api_client.dart';
import '../widgets/app_ui.dart';

/// GCP W2 · 试用器械库存台账 — GCP §2022 第28号 第22条 要求.
class DeviceInventoryScreen extends StatefulWidget {
  const DeviceInventoryScreen({super.key});

  @override
  State<DeviceInventoryScreen> createState() => _DeviceInventoryScreenState();
}

class _DeviceInventoryScreenState extends State<DeviceInventoryScreen>
    with SingleTickerProviderStateMixin {
  late final DeviceService _service =
      DeviceService(apiClient: ApiClient.instance);
  late final TabController _tab =
      TabController(length: 4, vsync: this);

  final Map<String, List<InvestigationalDevice>> _buckets = {
    'sealed': [],
    'in-use': [],
    'returned': [],
    'damaged': [],
  };
  final Map<String, bool> _loading = {
    'sealed': true,
    'in-use': true,
    'returned': true,
    'damaged': true,
  };
  final Map<String, int> _totals = {'sealed': 0, 'in-use': 0, 'returned': 0, 'damaged': 0};

  @override
  void initState() {
    super.initState();
    _loadAll();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _refreshBucket(_statusForTab());
    });
  }

  String _statusForTab() {
    switch (_tab.index) {
      case 1:
        return 'in-use';
      case 2:
        return 'returned';
      case 3:
        return 'damaged';
      default:
        return 'sealed';
    }
  }

  Future<void> _loadAll() async {
    for (final s in _buckets.keys) {
      await _refreshBucket(s);
    }
  }

  Future<void> _refreshBucket(String status) async {
    setState(() => _loading[status] = true);
    final res = await _service.listDevices(status: status);
    if (!mounted) return;
    setState(() {
      _loading[status] = false;
      if (res.success && res.data != null) {
        _buckets[status] = res.data!;
        _totals[status] = res.data!.length;
      }
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<InvestigationalDevice>(
      MaterialPageRoute(builder: (_) => const _DeviceCreateScreen()),
    );
    if (created != null && mounted) {
      _refreshBucket(_statusForTab());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已入库 ${created.serialNumber}')),
      );
    }
  }

  Future<void> _returnDevice(InvestigationalDevice d) async {
    final cond = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('归还器械 ${d.serialNumber}',
                    style: AppTheme.body
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.actionBlue),
                  title: const Text('完好归还'),
                  subtitle: const Text('入「returned」'),
                  onTap: () => Navigator.pop(ctx, 'returned'),
                ),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.statusPendingSign),
                  title: const Text('部分破损'),
                  subtitle: const Text('入「returned」 + 标记备注'),
                  onTap: () => Navigator.pop(ctx, 'returned'),
                ),
                ListTile(
                  leading: const Icon(Icons.dangerous_rounded,
                      color: AppTheme.statusPendingSign),
                  title: const Text('已损坏 / 报废'),
                  subtitle: const Text('入「damaged」'),
                  onTap: () => Navigator.pop(ctx, 'damaged'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (cond == null || !mounted) return;
    final res = await _service.returnDevice(
      deviceId: d.id,
      condition: cond,
    );
    if (!mounted) return;
    if (res.success) {
      _refreshBucket('sealed');
      _refreshBucket('in-use');
      _refreshBucket('returned');
      _refreshBucket('damaged');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('器械已$cond')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('归还失败：${res.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusForTab();
    final list = _buckets[status] ?? const [];
    final loading = _loading[status] ?? true;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('试用器械库存'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.actionBlue,
          unselectedLabelColor: AppTheme.textHint,
          indicatorColor: AppTheme.actionBlue,
          isScrollable: true,
          tabs: [
            Tab(text: '在库 (${_totals['sealed'] ?? 0})'),
            Tab(text: '在用 (${_totals['in-use'] ?? 0})'),
            Tab(text: '已归还 (${_totals['returned'] ?? 0})'),
            Tab(text: '已损坏 (${_totals['damaged'] ?? 0})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.actionBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('入库器械'),
        onPressed: _openCreate,
      ),
      body: TabBarView(
        controller: _tab,
        children: _buckets.keys
            .map((s) => _buildBucket(s, _buckets[s]!, _loading[s]!))
            .toList(),
      ),
    );
  }

  Widget _buildBucket(String status, List<InvestigationalDevice> list, bool loading) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) return _buildEmpty(status);
    return RefreshIndicator(
      onRefresh: () => _refreshBucket(status),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: list.length,
        itemBuilder: (_, i) => _DeviceCard(
          d: list[i],
          onReturn: status == 'in-use' ? () => _returnDevice(list[i]) : null,
        ),
      ),
    );
  }

  Widget _buildEmpty(String status) {
    final label = {
      'sealed': '仓库',
      'in-use': '在用',
      'returned': '归还',
      'damaged': '损坏',
    }[status]!;
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
            child: const Icon(Icons.inventory_2_outlined,
                size: 42, color: AppTheme.actionBlue),
          ),
          const SizedBox(height: 18),
          Text('「$label」暂无器械', style: AppTheme.body),
          const SizedBox(height: 6),
          Text(status == 'in-use'
              ? '已分配给受试者的器械会出现在这里'
              : '切换 tab 或入库器械试试'),
          const SizedBox(height: 4),
          Text('', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final InvestigationalDevice d;
  final VoidCallback? onReturn;
  const _DeviceCard({required this.d, this.onReturn});

  Color get _statusColor {
    switch (d.status) {
      case 'in-use':
        return AppTheme.statusPendingSign;
      case 'returned':
        return AppTheme.actionBlue;
      case 'damaged':
        return AppTheme.statusPendingSign;
      default:
        return AppTheme.textHint;
    }
  }

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
                  child: Text(d.modelName,
                      style: AppTheme.body
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                TypeChip(label: d.status, selected: d.inUse),
              ],
            ),
            const SizedBox(height: 4),
            Text('${d.deviceType} · ${d.manufacturer}', style: AppTheme.micro),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('批号', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 4),
                Text(d.lotNumber, style: AppTheme.micro),
                const SizedBox(width: 16),
                Text('SN', style: AppTheme.micro.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 4),
                Text(d.serialNumber, style: AppTheme.micro),
              ],
            ),
            if (d.expiryDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 14, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('有效期至 ${d.expiryDate!.year}-${_pad(d.expiryDate!.month)}-${_pad(d.expiryDate!.day)}',
                      style: AppTheme.micro),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: _statusColor),
                const SizedBox(width: 4),
                Text(d.currentLocation == 'warehouse'
                    ? '主仓库'
                    : (d.currentLocation == 'center'
                        ? '分中心 ${d.currentCenterId}'
                        : '受试者使用中')),
                const Spacer(),
                if (onReturn != null)
                  TextButton(
                    onPressed: onReturn,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('归还'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int v) => v < 10 ? '0$v' : '$v';
}

/// 器械入库页.
class _DeviceCreateScreen extends StatefulWidget {
  const _DeviceCreateScreen();
  @override
  State<_DeviceCreateScreen> createState() => _DeviceCreateScreenState();
}

class _DeviceCreateScreenState extends State<_DeviceCreateScreen> {
  late final DeviceService _service =
      DeviceService(apiClient: ApiClient.instance);
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController(text: '创面敷料');
  final _model = TextEditingController(text: 'HydroFlex-200');
  final _mfg = TextEditingController(text: '笃行医疗科技');
  final _lot = TextEditingController();
  final _sn = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _type.dispose();
    _model.dispose();
    _mfg.dispose();
    _lot.dispose();
    _sn.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final res = await _service.createDevice(
      deviceType: _type.text.trim(),
      modelName: _model.text.trim(),
      manufacturer: _mfg.text.trim(),
      lotNumber: _lot.text.trim(),
      serialNumber: _sn.text.trim(),
      manufactureDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      qcPassedAt: DateTime.now().toIso8601String().substring(0, 10),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success && res.data != null) {
      Navigator.pop(context, res.data);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('入库失败：${res.message}')),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
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
      appBar: AppBar(title: const Text('入库试用器械')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _field(_type, '器械类别', '创面敷料', required: true),
            _field(_model, '型号', 'HydroFlex-200', required: true),
            _field(_mfg, '生产方', '笃行医疗科技', required: true),
            _field(_lot, '批号', 'LOT-2026-A04', required: true),
            _field(_sn, '序列号', 'SN-004001', required: true),
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
                  : const Text('入库'),
            ),
          ],
        ),
      ),
    );
  }
}
