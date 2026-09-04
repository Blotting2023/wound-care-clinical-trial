import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Shared UI components implementing the design spec (UI设计/README.md §3.4).

/// White card: radius 18, 1px light border, no shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

/// Section header used above cards ("最近评估" etc.).
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.title.copyWith(fontSize: 18));
}

/// Status chip: 待签名 (orange) / 已锁定 (green) / other states.
class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip.pendingSign({super.key})
      : label = '待签名',
        _color = AppTheme.statusPendingSign;
  const StatusChip.locked({super.key})
      : label = '已锁定',
        _color = AppTheme.statusLocked;
  const StatusChip.custom({super.key, required String this.label})
      : _color = AppTheme.textSecondary;

  final Color _color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

/// Patient type chip: 住院 / 门诊 / 随访中.
class TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  const TypeChip({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? AppTheme.actionBlue : Colors.transparent,
        border: Border.all(
          color: selected ? AppTheme.actionBlue : AppTheme.cardBorder,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

/// Filter chip row: 全部(active blue) / 住院 / 门诊 / 随访中.
class FilterChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const FilterChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppTheme.actionBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? AppTheme.actionBlue : AppTheme.cardBorder,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Step indicator: e.g. "1/4 拍照测量" with progress dots.
class StepIndicator extends StatelessWidget {
  final int step; // 1-based
  final int total;
  final String label;
  const StepIndicator({
    super.key,
    required this.step,
    this.total = 4,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$step/$total',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.actionBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: step / total,
                  minHeight: 4,
                  backgroundColor: AppTheme.cardBorder,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.actionBlue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTheme.micro),
      ],
    );
  }
}

/// Metric triple grid: 面积 / 最长径 / 宽度.
class MetricTriple extends StatelessWidget {
  final List<({String label, String value, String unit})> metrics;
  const MetricTriple({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            Container(
                width: 1, height: 36, color: AppTheme.cardBorder, margin: const EdgeInsets.symmetric(horizontal: 4)),
          Expanded(
            child: Column(
              children: [
                Text(metrics[i].value, style: AppTheme.metricNumber),
                const SizedBox(height: 2),
                Text('${metrics[i].label} (${metrics[i].unit})',
                    style: AppTheme.micro),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tissue composition horizontal bar: 肉芽/腐肉/坏死 with legend.
class TissueBar extends StatelessWidget {
  final double granulation; // 0..1
  final double slough; // 0..1
  final double necrosis; // 0..1
  const TissueBar({
    super.key,
    required this.granulation,
    required this.slough,
    required this.necrosis,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('肉芽', granulation, AppTheme.tissueGranulation),
      ('腐肉', slough, AppTheme.tissueSlough),
      ('坏死', necrosis, AppTheme.tissueNecrosis),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, value, color) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(name, style: AppTheme.caption),
                const Spacer(),
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: AppTheme.pageBackground,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('${(value * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: AppTheme.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Scale option chip (VSS items / wound stage): selected = blue fill.
class ScaleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const ScaleChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.actionBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.actionBlue : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Pill bottom tab bar: 首页 / 患者 / 评估 / 我的.
class PillTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const PillTabBar(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.people_outline_rounded, Icons.people_rounded, '患者'),
    (Icons.assessment_outlined, Icons.assessment_rounded, '评估'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i == currentIndex
                            ? AppTheme.actionBlue
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        i == currentIndex
                            ? _items[i].$2
                            : _items[i].$1,
                        size: 20,
                        color: i == currentIndex
                            ? Colors.white
                            : AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _items[i].$3,
                      style: TextStyle(
                        fontSize: 10,
                        color: i == currentIndex
                            ? AppTheme.actionBlue
                            : AppTheme.textHint,
                        fontWeight: i == currentIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
