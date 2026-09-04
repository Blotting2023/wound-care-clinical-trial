import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/app_ui.dart';

/// 简易教程：讲清一次完整创面评估的操作路径与合规要点。
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    (
      icon: Icons.person_search_rounded,
      title: '1. 找到患者',
      body: '首页「最近评估」或底部「患者」页 → 点击患者卡片进入患者详情页。'
            '有记录待签名时，卡片上会显示橙色「待签名」标签。',
    ),
    (
      icon: Icons.add_circle_outline_rounded,
      title: '2. 新增记录',
      body: '点底部「新增记录」→ 选择已有部位，或点「新部位」在人体图上选位置。'
            '已建立记录且待签名的部位，在列表上带橙色标签。',
    ),
    (
      icon: Icons.photo_camera_rounded,
      title: '3. 拍照采集',
      body: '光线充足、镜头垂直、距创面 15–20 cm。系统自动识别轮廓并给出'
            '面积、最长径、宽度与组织构成。演示模式下会自动生成模拟照片。',
    ),
    (
      icon: Icons.tune_rounded,
      title: '4. 核对并修正测量',
      body: '点照片右上角「调整」进入全屏：\n'
            '· 调整关键点：拖动蓝点修正 AI 轮廓\n'
            '· 手绘轮廓：沿创面边缘画一圈，松手自动闭合\n'
            '· 拖动青色/橙色端点，手动指定最长径与宽度位置\n'
            '底部三个数值随操作实时更新。',
    ),
    (
      icon: Icons.assessment_rounded,
      title: '5. 完成临床量表',
      body: 'NRS 疼痛评分 0–10 单选；VSS 温哥华瘢痕量表四项单选；'
            '再选创面分期。橙色边框与「前值」标注为上一次记录的评分，便于对比。',
    ),
    (
      icon: Icons.lock_rounded,
      title: '6. 电子签名锁定',
      body: '输入 6 位签名 PIN 后确认，记录立即锁定，任何内容不可修改，'
            '全部操作纳入审计追踪（符合 GCP / 21 CFR Part 11）。签名后自动返回患者详情页。',
    ),
    (
      icon: Icons.show_chart_rounded,
      title: '7. 回看与追踪',
      body: '进入部位详情页：顶部展示最近一次记录的创面照片与关键数据，'
            '下方为面积变化趋势曲线与评估历史；点击某条记录可只读查看该次评估全量数据。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('简易教程'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.noticeBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppTheme.actionBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '一次评估 = 拍照 → 核对测量 → 填量表 → 签名锁定。'
                    '共四步，约 1 分钟完成。',
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.actionBlue, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('操作步骤'),
          const SizedBox(height: 12),
          for (final s in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.actionBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon,
                              size: 18, color: AppTheme.actionBlue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.title,
                              style: AppTheme.body.copyWith(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(s.body,
                        style: AppTheme.caption
                            .copyWith(height: 1.7, fontSize: 13)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          const SectionTitle('常见问题'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _FaqItem(
                  q: 'AI 识别的轮廓不准怎么办？',
                  a: '进入全屏「调整」页，用「手绘轮廓」沿创面边缘画一圈即可，'
                      '面积与长宽会按新轮廓实时重算，无需保留 AI 结果。',
                ),
                _FaqItem(
                  q: '签名后还能改数据吗？',
                  a: '不能。已锁定记录为只读，如需更正必须通过修订流程，'
                      '原记录与修订记录均会保留在审计追踪中。',
                ),
                _FaqItem(
                  q: '为什么量表里有橙色选项？',
                  a: '橙色边框与「前值」标注代表该部位上一次评估的评分，'
                      '用于快速对比本次变化，不是推荐值。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Q  ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.actionBlue)),
              Expanded(
                child: Text(q,
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w600, height: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A  ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHint)),
              Expanded(
                child: Text(a,
                    style: AppTheme.micro
                        .copyWith(height: 1.7, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
