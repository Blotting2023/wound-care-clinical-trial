import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'app_ui.dart';

/// VSS 温哥华瘢痕量表（设计稿 05）：四项评分，chip 单选。
/// 血管分布 0-3 / 厚度 0-3 / 柔软度 0-5 / 色素沉着 0-3，总 7 分（厚度+柔软度封顶计分）。
/// previous* 参数提示上一次评估的分值（橙色边框）。
class VssScaleWidget extends StatefulWidget {
  final ValueChanged<int?> onVascularity;
  final ValueChanged<int?> onPigmentation;
  final ValueChanged<int?> onPliability;
  final ValueChanged<int?> onHeight;
  final int? previousVascularity;
  final int? previousPigmentation;
  final int? previousPliability;
  final int? previousHeight;
  const VssScaleWidget({
    super.key,
    required this.onVascularity,
    required this.onPigmentation,
    required this.onPliability,
    required this.onHeight,
    this.previousVascularity,
    this.previousPigmentation,
    this.previousPliability,
    this.previousHeight,
  });

  @override
  State<VssScaleWidget> createState() => _VssScaleWidgetState();
}

class _VssScaleWidgetState extends State<VssScaleWidget> {
  int? _vascularity, _pigmentation, _pliability, _height;

  int get _total =>
      (_vascularity ?? 0) +
      (_pigmentation ?? 0) +
      (_pliability ?? 0) +
      (_height ?? 0);

  Widget _scale(String label, String range, int max, int? current,
      int? previous, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTheme.body.copyWith(fontSize: 14)),
              const SizedBox(width: 4),
              Text(range, style: AppTheme.micro),
              const Spacer(),
              if (previous != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('前值 $previous',
                      style: AppTheme.micro.copyWith(
                          color: AppTheme.statusPendingSign,
                          fontWeight: FontWeight.w600)),
                ),
              if (current != null)
                Text('$current 分',
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.actionBlue,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              max + 1,
              (i) => _CompactChip(
                label: '$i',
                selected: current == i,
                isPrevious: previous == i && current != i,
                onTap: () {
                  setState(() => onChanged(current == i ? null : i));
                },
              ),
            ),
          ),
        ],
      ),
    );
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
                child: Text('VSS 温哥华瘢痕量表',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Text('总 $_total 分',
                  style: AppTheme.caption.copyWith(
                      color: AppTheme.actionBlue,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _scale('血管分布', '0–3', 3, _vascularity, widget.previousVascularity,
              (v) { _vascularity = v; widget.onVascularity(v); }),
          _scale('厚度', '0–3', 3, _height, widget.previousHeight,
              (v) { _height = v; widget.onHeight(v); }),
          _scale('柔软度', '0–5', 5, _pliability, widget.previousPliability,
              (v) { _pliability = v; widget.onPliability(v); }),
          _scale('色素沉着', '0–3', 3, _pigmentation, widget.previousPigmentation,
              (v) { _pigmentation = v; widget.onPigmentation(v); }),
        ],
      ),
    );
  }
}

/// Smaller, more compact version of ScaleChip for dense layouts.
class _CompactChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isPrevious;
  final VoidCallback? onTap;
  const _CompactChip(
      {required this.label, this.selected = false, this.isPrevious = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.actionBlue
              : isPrevious
                  ? const Color(0xFFFFF7E6)
                  : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? AppTheme.actionBlue
                : isPrevious
                    ? AppTheme.statusPendingSign
                    : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : isPrevious
                    ? AppTheme.statusPendingSign
                    : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
