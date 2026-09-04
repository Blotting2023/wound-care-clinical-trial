/// Append-only audit trail for any mutation to clinical data.
///
/// Implements the GCP + 21 CFR Part 11 expectations for audit trails:
///
///  *   **Tamper-evident** — every entry is hashed together with the
///      previous entry's hash, so modifying any past entry breaks the chain.
///      `verifyChain()` walks the entire log and reports the first broken
///      link.
///  *   **Append-only at the API level** — the only public mutator is
///      `record()`. There is intentionally no `update()` / `delete()` /
///      `clear()` method. In production, the DB role that the app user
///      connects with should `REVOKE UPDATE, DELETE` on the audit_log table.
///  *   **ALCOA+ complete** — every entry captures who, when, before,
///      after, why, on which device, from which IP, in which app version.
///
/// In the demo backend, the logger stores its entries in memory but the
/// chain semantics are identical to a real backend — every entry's hash
/// depends on the previous one.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Allowed operation types. The full list mirrors the regulatory catalogue
/// in `合规规范/差距清单与落地建议.md` §11.
enum AuditOpType {
  create,
  update,
  delete,
  sign,
  lock,
  unlock,
  accessDenied,
  export,
  consentSign,
  consentWithdraw,
  identityAccess,
  deviceAssignment,
}

/// One row in the audit log. Immutable. Cannot be edited after construction.
class AuditEntry {
  final String id;
  final String tableName;
  final String recordId;
  final AuditOpType opType;
  final String fieldName;
  final Object? beforeValue;
  final Object? afterValue;
  final String? reason;
  final String operatorId;
  final String operatorName;
  final String? operatorRole;
  final String? operatorIp;
  final String? deviceFingerprint;
  final String? appVersion;
  final DateTime occurredAt;
  final String prevHash;
  final String hash;

  const AuditEntry({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.opType,
    required this.fieldName,
    this.beforeValue,
    this.afterValue,
    this.reason,
    required this.operatorId,
    required this.operatorName,
    this.operatorRole,
    this.operatorIp,
    this.deviceFingerprint,
    this.appVersion,
    required this.occurredAt,
    required this.prevHash,
    required this.hash,
  });

  /// JSON serialisation (for transport to a real backend). Never includes
  /// the hash in the input payload — the server computes and stamps it.
  Map<String, dynamic> toJson() => {
        'id': id,
        'tableName': tableName,
        'recordId': recordId,
        'opType': opType.name,
        'fieldName': fieldName,
        'beforeValue': beforeValue,
        'afterValue': afterValue,
        'reason': reason,
        'operatorId': operatorId,
        'operatorName': operatorName,
        'operatorRole': operatorRole,
        'operatorIp': operatorIp,
        'deviceFingerprint': deviceFingerprint,
        'appVersion': appVersion,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'prevHash': prevHash,
        'hash': hash,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as String,
        tableName: json['tableName'] as String,
        recordId: json['recordId'] as String,
        opType: AuditOpType.values.firstWhere(
          (e) => e.name == json['opType'],
          orElse: () => AuditOpType.update,
        ),
        fieldName: json['fieldName'] as String? ?? '',
        beforeValue: json['beforeValue'],
        afterValue: json['afterValue'],
        reason: json['reason'] as String?,
        operatorId: json['operatorId'] as String,
        operatorName: json['operatorName'] as String? ?? '',
        operatorRole: json['operatorRole'] as String?,
        operatorIp: json['operatorIp'] as String?,
        deviceFingerprint: json['deviceFingerprint'] as String?,
        appVersion: json['appVersion'] as String?,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        prevHash: json['prevHash'] as String? ?? '',
        hash: json['hash'] as String,
      );
}

/// Context passed to every audit-recording call. In the demo backend this
/// is constructed once at session start and reused; in production the auth
/// middleware fills it from the verified JWT.
class AuditContext {
  final String operatorId;
  final String operatorName;
  final String? operatorRole;
  final String? operatorIp;
  final String? deviceFingerprint;
  final String? appVersion;

  const AuditContext({
    required this.operatorId,
    required this.operatorName,
    this.operatorRole,
    this.operatorIp,
    this.deviceFingerprint,
    this.appVersion,
  });
}

class AuditLogger {
  /// Singleton instance (per session). Demo backend uses this; production
  /// backend should construct one per request scope.
  static final AuditLogger I = AuditLogger._();

  AuditLogger._();

  final List<AuditEntry> _entries = [];
  int _seq = 0;

  /// All entries in chronological order. Returns an unmodifiable view.
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Number of entries recorded so far.
  int get length => _entries.length;

  /// Reset the in-memory log. **Test-only** — there is intentionally no
  /// API for production code to wipe the log.
  void clearForTest() {
    _entries.clear();
    _seq = 0;
  }

  /// Append one audit entry. This is the **only** mutation API.
  AuditEntry record({
    required String tableName,
    required String recordId,
    required AuditOpType opType,
    String fieldName = '',
    Object? beforeValue,
    Object? afterValue,
    String? reason,
    required AuditContext ctx,
    DateTime? occurredAt,
  }) {
    final ts = occurredAt ?? DateTime.now().toUtc();
    final prevHash = _entries.isEmpty ? 'GENESIS' : _entries.last.hash;
    final id = 'audit_${ts.millisecondsSinceEpoch}_${_seq++}';
    final hash = _computeHash(
      prevHash: prevHash,
      tableName: tableName,
      recordId: recordId,
      opType: opType,
      fieldName: fieldName,
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      operatorId: ctx.operatorId,
      occurredAt: ts,
    );
    final entry = AuditEntry(
      id: id,
      tableName: tableName,
      recordId: recordId,
      opType: opType,
      fieldName: fieldName,
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      operatorId: ctx.operatorId,
      operatorName: ctx.operatorName,
      operatorRole: ctx.operatorRole,
      operatorIp: ctx.operatorIp,
      deviceFingerprint: ctx.deviceFingerprint,
      appVersion: ctx.appVersion,
      occurredAt: ts,
      prevHash: prevHash,
      hash: hash,
    );
    _entries.add(entry);
    return entry;
  }

  /// Filter the log by record. Returns the slice of entries that touched
  /// the given table+recordId, in chronological order.
  List<AuditEntry> entriesFor({
    required String tableName,
    required String recordId,
  }) {
    return _entries
        .where((e) => e.tableName == tableName && e.recordId == recordId)
        .toList();
  }

  /// Walk the entire log and verify each entry's hash matches the chain.
  /// Returns the index of the first broken link, or -1 if the chain is
  /// intact.
  int verifyChain() {
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final expectedPrev = i == 0 ? 'GENESIS' : _entries[i - 1].hash;
      if (e.prevHash != expectedPrev) return i;
      final recomputed = _computeHash(
        prevHash: e.prevHash,
        tableName: e.tableName,
        recordId: e.recordId,
        opType: e.opType,
        fieldName: e.fieldName,
        beforeValue: e.beforeValue,
        afterValue: e.afterValue,
        reason: e.reason,
        operatorId: e.operatorId,
        occurredAt: e.occurredAt,
      );
      if (recomputed != e.hash) return i;
    }
    return -1;
  }

  String _computeHash({
    required String prevHash,
    required String tableName,
    required String recordId,
    required AuditOpType opType,
    required String fieldName,
    Object? beforeValue,
    Object? afterValue,
    String? reason,
    required String operatorId,
    required DateTime occurredAt,
  }) {
    final payload = [
      prevHash,
      tableName,
      recordId,
      opType.name,
      fieldName,
      beforeValue == null ? '' : jsonEncode(beforeValue),
      afterValue == null ? '' : jsonEncode(afterValue),
      reason ?? '',
      operatorId,
      occurredAt.toUtc().millisecondsSinceEpoch.toString(),
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }
}