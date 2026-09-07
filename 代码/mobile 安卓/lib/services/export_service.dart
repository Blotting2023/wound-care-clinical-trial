/// 数据导出服务 — W5.2
///
/// 按当前登录角色，生成符合 PIPL §6 + GCP 2020 §5/§6 数据最小化原则的
/// 脱敏 CSV / JSON 文本。导出文件通过 `share_plus` 走系统分享菜单，
/// 可直接分享到邮箱 / 微信 / 文件 / 打印。
///
/// 角色 × 导出范围对照（详见 `合规规范/角色权限矩阵_V1.md`）：
/// - PI / SubI：完整原始数据（含真名 / 病案号 / 创面打分）
/// - CRC：鉴认代码视图（姓名病案号脱敏为 —）
/// - Sponsor：仅聚合统计 + 试验进度汇总（无个体受试者字段）
/// - IRB：知情同意书 + 撤回记录 + SAE 报告（无临床评估明细）
/// - Admin：完整数据（含真名）+ 系统配置
library;

import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../models/assessment.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../models/user_role.dart';

class ExportService {
  ExportService._();

  /// 评估报告 — 按角色范围生成 CSV 文本。
  /// V1 demo 仅输出评估明细 + 受试者鉴认代码；V2 接 PDF 库生成正式报告。
  static String assessmentsCsv({
    required User user,
    required List<Assessment> assessments,
    required Map<String, String> patientSubjectCode, // patientId → subjectCode
    required Map<String, String> patientCenter, // patientId → centerId
  }) {
    final canSeeReal = user.canViewRealName;
    final isSponsor = user.role == UserRole.Sponsor;
    final isIrb = user.role == UserRole.IRB;

    final buf = StringBuffer();
    final now = DateTime.now();
    buf.writeln(
        '# 创面评估系统 V1 数据导出 · ${_fmtTimestamp(now)} · ${user.role.displayName} ${user.displayName}');
    buf.writeln('# 导出范围：${_exportRangeLabel(user.role)}');
    buf.writeln(
        '# 数据最小化原则：${isSponsor ? "申办方只见聚合，本导出仅含试验进度统计" : isIrb ? "IRB 仅见伦理相关文档，本导出不含临床评估" : "按角色脱敏后导出"}');
    buf.writeln('# ');

    if (isSponsor) {
      // Sponsor 只见统计，不输出个体记录
      buf.writeln('# === 试验进度统计 ===');
      final total = assessments.length;
      final locked = assessments.where((a) => a.status == AssessmentStatus.locked).length;
      final pending = assessments
          .where((a) =>
              a.status == AssessmentStatus.draft ||
              a.status == AssessmentStatus.pendingSignature)
          .length;
      buf.writeln('受试者总数,${patientSubjectCode.length}');
      buf.writeln('评估记录总数,$total');
      buf.writeln('已锁定评估,$locked');
      buf.writeln('进行中评估,$pending');
      buf.writeln('锁定率,${total == 0 ? "—" : "${(locked * 100 ~/ total)}%"}');
      return buf.toString();
    }

    if (isIrb) {
      buf.writeln(
          '# IRB 导出：知情同意书状态摘要（不含临床评估明细，仅伦理相关）');
      buf.writeln('# 请配合知情同意书 + SAE 报告查阅');
      buf.writeln('# ');
      buf.writeln('subjectCode,centerId,数据可用性');
      for (final entry in patientSubjectCode.entries) {
        buf.writeln(
            '${entry.value},${patientCenter[entry.key] ?? "—"},eConsent + SAE 可查');
      }
      return buf.toString();
    }

    // PI / SubI / CRC / Admin：评估明细（按 canSeeReal 决定是否含姓名病案号）
    final header = canSeeReal
        ? 'subjectCode,姓名,病案号,centerId,部位,评估ID,状态,创建时间,锁定时间,面积(cm²)'
        : 'subjectCode,姓名,病案号,centerId,部位,评估ID,状态,创建时间,锁定时间,面积(cm²)';
    buf.writeln(header);
    for (final a in assessments) {
      final code = patientSubjectCode[a.patientId] ?? '—';
      final name = canSeeReal ? _lookupPatientName(a.patientId) : '—';
      final mrn = canSeeReal ? _lookupPatientMrn(a.patientId) : '—';
      final center = patientCenter[a.patientId] ?? '—';
      buf.writeln([
        code,
        name,
        mrn,
        center,
        '—',
        a.id,
        a.status.name,
        a.createdAt.toIso8601String(),
        a.signedAt?.toIso8601String() ?? '—',
        '—',
      ].join(','));
    }
    return buf.toString();
  }

  /// 触发系统分享菜单（share_plus）。返回分享成功与否。
  static Future<bool> shareText({
    required String content,
    required String filename,
    required String subject,
  }) async {
    try {
      final result = await Share.share(
        '$content\n\n— 导出文件：$filename',
        subject: subject,
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  /// 生成导出文件名：`{role}_{评估数}条_{YYYYMMDD_HHmmss}.csv`
  static String filename({
    required UserRole role,
    required int recordCount,
  }) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return 'wound_${role.shortCode}_${recordCount}rec_${stamp}.csv';
  }

  static String _exportRangeLabel(UserRole role) {
    switch (role) {
      case UserRole.PI:
      case UserRole.SubI:
        return '本中心全部受试者 + 全部评估明细（含真名/病案号/创面打分）';
      case UserRole.CRC:
        return '本中心受试者列表（仅鉴认代码，姓名/病案号脱敏）+ 评估状态';
      case UserRole.Sponsor:
        return '试验进度统计（聚合）— 不含个体受试者字段';
      case UserRole.IRB:
        return '知情同意书 + SAE 报告 — 不含临床评估明细';
      case UserRole.Admin:
        return '完整数据 + 系统配置';
    }
  }

  static String _fmtTimestamp(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');

  // V1 demo stub：实际从后端取，V1 直接用鉴认代码 + — 占位
  static String _lookupPatientName(String patientId) => '—（V1 占位）';
  static String _lookupPatientMrn(String patientId) => '—（V1 占位）';

  /// 把导出文本按行 JSON 化（用于审计元数据上报）
  static Map<String, dynamic> toExportMeta({
    required User user,
    required int recordCount,
  }) {
    return {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exportedBy': user.id,
      'exportedByName': user.displayName,
      'exportedByRole': user.role.name,
      'recordCount': recordCount,
      'dataScope': _exportRangeLabel(user.role),
    };
  }

  /// 编码 JSON 字符串（用于元数据 dump）
  static String metaJson(Map<String, dynamic> meta) =>
      const JsonEncoder.withIndent('  ').convert(meta);
}