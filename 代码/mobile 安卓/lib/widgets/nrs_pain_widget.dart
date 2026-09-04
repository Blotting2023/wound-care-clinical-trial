import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'app_ui.dart';

/// NRS 疼痛评分（设计稿 05）：0 无痛 → 10 剧痛，单选列表。
/// [previousValue] 提示上一次评估的分值。
class NrsPainWidget extends StatefulWidget {
  final ValueChanged<int?> onChanged;
  final int? previousValue;
  const NrsPainWidget({super.key, required this.onChanged, this.previousValue});

  @override
  State<NrsPainWidget> createState() => _NrsPainWidgetState();
}

class _NrsPainWidgetState extends State<NrsPainWidget> {
  int? _selected;

  String _label(int v) {
    if (v <= 0) return '无痛';
    if (v <= 3) return '轻度';
    if (v <= 6) return '中度';
    if (v <= 9) return '重度';
    return '剧痛';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('NRS 疼痛评分',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (_selected != null)
                Text(
                  '$_selected 分 · ${_label(_selected!)}',
                  style: AppTheme.caption.copyWith(
                      color: AppTheme.actionBlue, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (widget.previousValue != null) ...[
            const SizedBox(height: 4),
            Text('前值 ${widget.previousValue} 分',
                style: AppTheme.micro.copyWith(color: AppTheme.statusPendingSign)),
          ],
          const SizedBox(height: 10),
          // 0-10 单选网格
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i <= 10; i++)
                _NrsChip(
                  value: i,
                  label: '$i',
                  subtitle: i == 0 ? '无痛' : (i == 10 ? '剧痛' : null),
                  selected: _selected == i,
                  isPrevious: widget.previousValue == i,
                  onTap: () {
                    setState(() => _selected = i);
                    widget.onChanged(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 无痛', style: AppTheme.micro),
              Text('10 剧痛', style: AppTheme.micro),
            ],
          ),
        ],
      ),
    );
  }
}

class _NrsChip extends StatelessWidget {
  final int value;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool isPrevious;
  final VoidCallback onTap;

  const _NrsChip({
    required this.value,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.isPrevious,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppTheme.actionBlue
        : isPrevious
            ? const Color(0xFFFFF7E6)
            : Colors.white;
    final fg = selected
        ? Colors.white
        : isPrevious
            ? AppTheme.statusPendingSign
            : AppTheme.textSecondary;
    final border = selected
        ? AppTheme.actionBlue
        : isPrevious
            ? AppTheme.statusPendingSign
            : AppTheme.cardBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: subtitle != null ? 52 : 36,
        height: subtitle != null ? 44 : 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: subtitle != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                  Text(subtitle!,
                      style: TextStyle(fontSize: 9, color: fg)),
                ],
              )
            : Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
      ),
    );
  }
}
