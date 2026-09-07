/// 数据留存期工具 — NMPA 2022 §63 医疗器械 GCP 要求：
/// "临床试验数据保存期限为试验终止后至少 10 年"。
///
/// V1 demo 仅计算并展示留存截止日；V4 接真实数据销毁流程。
library;

import 'package:flutter/material.dart';

/// 医疗器械 GCP 规定的临床试验数据留存期：试验完成后 10 年。
const Duration kClinicalRetention = Duration(days: 365 * 10);

/// 按"试验完成时间 + 10 年"计算留存截止日。
/// 试验完成日 = 最后一条评估的 createdAt（或锁定时间）。
DateTime retentionUntil(DateTime trialEndAt) {
  return trialEndAt.add(kClinicalRetention);
}

/// 格式化为 'YYYY 年 MM 月 DD 日'（中文长格式，纯数字组装避免依赖 locale）
String fmtRetentionDate(DateTime d) {
  return '${d.year} 年 ${d.month} 月 ${d.day} 日';
}

/// 距今还剩多少年（用于 UI 标识"剩余 X 年"）。
String fmtYearsRemaining(DateTime until) {
  final now = DateTime.now();
  if (until.isBefore(now)) return '已过期';
  final daysLeft = until.difference(now).inDays;
  final yearsLeft = (daysLeft / 365).floor();
  if (yearsLeft >= 1) return '剩余 $yearsLeft 年';
  final monthsLeft = (daysLeft / 30).floor();
  if (monthsLeft >= 1) return '剩余 $monthsLeft 月';
  return '剩余 $daysLeft 天';
}

/// 留存标识的 UI 主题（颜色）。
/// 试验终止后 10 年内 = 正常；过期 = 警示色（V1 demo 仅展示）。
Color retentionColor(DateTime until) {
  final now = DateTime.now();
  if (until.isBefore(now)) return Colors.red.shade400;
  final daysLeft = until.difference(now).inDays;
  if (daysLeft < 365) return Colors.orange.shade400;
  return Colors.green.shade600;
}

/// 简短标识（"10 年"）+ 完整标识（"留存至 YYYY 年 M 月 D 日"）
class RetentionBadge {
  final DateTime? trialEndAt;
  const RetentionBadge(this.trialEndAt);

  bool get hasEnd => trialEndAt != null;
  DateTime get until => retentionUntil(trialEndAt!);

  String get shortLabel =>
      hasEnd ? fmtYearsRemaining(until) : '临床数据留存 10 年';
  String get fullLabel =>
      hasEnd ? '留存至 ${fmtRetentionDate(until)}' : '临床数据留存期 10 年';
  Color get color => hasEnd ? retentionColor(until) : Colors.green.shade600;
}