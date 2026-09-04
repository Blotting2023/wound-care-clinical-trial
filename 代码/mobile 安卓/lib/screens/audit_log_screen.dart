import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/api_client.dart';
import '../services/audit_logger.dart';
import '../widgets/app_ui.dart';

/// Read-only viewer for the in-memory audit log.
///
/// **GCP note** — this is the regulatory audit log (§57–63 of the 2022 GCP
/// regulation). It is strictly append-only: the only API to add an entry is
/// `AuditLogger.I.record(...)`. There is intentionally no UI to delete or
/// edit entries.
///
/// In production this screen renders entries from the server-side audit log
/// table (which has `REVOKE UPDATE, DELETE` at the DB level). Here we read
/// the same data via the demo `/audit-log` endpoint so the chain semantics
/// can be exercised end-to-end.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<_AuditSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AuditSnapshot> _load() async {
    try {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/audit-log',
      );
      final list = (res.data?['content'] as List? ?? [])
          .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final chainValid = res.data?['chainValid'] as bool? ?? false;
      return _AuditSnapshot(entries: list, chainValid: chainValid);
    } on DioException catch (e) {
      return _AuditSnapshot(
        entries: const [],
        chainValid: false,
        error: e.response?.data?['message']?.toString() ?? e.message ?? '加载失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('审计日志 · GCP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<_AuditSnapshot>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.error != null) {
            return Center(child: Text('加载失败：${data.error}'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(data),
              const Divider(height: 1),
              Expanded(child: _buildList(data.entries)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(_AuditSnapshot snap) {
    final byOp = <String, int>{};
    for (final e in snap.entries) {
      byOp[e.opType.name] = (byOp[e.opType.name] ?? 0) + 1;
    }
    final chains = snap.chainValid ? '✅ 哈希链完整' : '❌ 哈希链断裂';
    return Container(
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('共 ${snap.entries.length} 条记录',
                    style: AppTheme.title.copyWith(fontSize: 17)),
              ),
              Text(
                chains,
                style: AppTheme.body.copyWith(
                  color: snap.chainValid ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: byOp.entries
                .map((kv) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pageBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${kv.key} ×${kv.value}',
                          style: AppTheme.micro),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AuditEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('暂无审计记录'));
    }
    final sorted = List<AuditEntry>.from(entries.reversed);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _entryCard(sorted[i]),
    );
  }

  Widget _entryCard(AuditEntry e) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _opColor(e.opType).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.opType.name.toUpperCase(),
                  style: AppTheme.micro.copyWith(
                    color: _opColor(e.opType),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.tableName} · ${e.recordId}',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _fmtTime(e.occurredAt),
                style: AppTheme.micro,
              ),
            ],
          ),
          if (e.fieldName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('字段：${e.fieldName}', style: AppTheme.micro),
          ],
          if (e.beforeValue != null || e.afterValue != null) ...[
            const SizedBox(height: 4),
            Text('${e.beforeValue ?? '∅'}  →  ${e.afterValue ?? '∅'}',
                style: AppTheme.micro),
          ],
          if (e.reason != null && e.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('原因：${e.reason}', style: AppTheme.micro),
          ],
          const SizedBox(height: 6),
          Text(
            '操作员：${e.operatorName} (${e.operatorId})'
            '${e.operatorRole != null ? ' · ${e.operatorRole}' : ''}',
            style: AppTheme.micro,
          ),
          if (e.deviceFingerprint != null) ...[
            const SizedBox(height: 2),
            Text('设备：${e.deviceFingerprint}', style: AppTheme.micro),
          ],
          const SizedBox(height: 4),
          Text(
            'hash：${e.hash.substring(0, 12)}…',
            style: AppTheme.micro.copyWith(
                color: AppTheme.textHint, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Color _opColor(AuditOpType t) {
    switch (t) {
      case AuditOpType.create:
        return const Color(0xFF1E7A4D);
      case AuditOpType.update:
        return const Color(0xFF0066CC);
      case AuditOpType.delete:
        return const Color(0xFFB32D00);
      case AuditOpType.sign:
        return const Color(0xFF6B21A8);
      case AuditOpType.lock:
        return const Color(0xFF374151);
      case AuditOpType.unlock:
        return const Color(0xFFB45309);
      case AuditOpType.accessDenied:
        return const Color(0xFFB32D00);
      case AuditOpType.export:
        return const Color(0xFF0F766E);
      case AuditOpType.consentSign:
        return const Color(0xFF6B21A8);
      case AuditOpType.consentWithdraw:
        return const Color(0xFFB45309);
      case AuditOpType.identityAccess:
        return const Color(0xFFB32D00);
      case AuditOpType.deviceAssignment:
        return const Color(0xFF0066CC);
    }
  }

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}

class _AuditSnapshot {
  final List<AuditEntry> entries;
  final bool chainValid;
  final String? error;
  _AuditSnapshot(
      {required this.entries, required this.chainValid, this.error});
}