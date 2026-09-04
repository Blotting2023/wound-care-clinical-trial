import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/app_ui.dart';
import 'home_screen.dart';
import 'patient_list_screen.dart';
import 'settings_screen.dart';

/// App 主壳：胶囊 Tab Bar（首页 / 患者 / 评估 / 我的）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _homeRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: IndexedStack(
        index: _index,
        children: [
          // 切回首页时重建，刷新概览统计与最近评估。
          HomeScreen(
            key: ValueKey('home_$_homeRefresh'),
            onGoPatients: () => setState(() => _index = 1),
          ),
          const PatientListScreen(embedded: true),
          const _AssessmentsTab(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: PillTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          if (i == 0) _homeRefresh++;
          _index = i;
        }),
      ),
    );
  }
}

/// 「评估」Tab：最近评估入口（demo 汇总说明 + 引导）。
class _AssessmentsTab extends StatelessWidget {
  const _AssessmentsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('评估')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('评估工作流', style: AppTheme.title),
                const SizedBox(height: 8),
                Text(
                  '完整评估流程共 4 步：\n1. 拍照 + AI 测量（自动面积 / 最长径 / 宽度 / 组织构成）\n2. 临床量表评估（VSS · NRS · 创面分期）\n3. 医生确认测量结果\n4. 电子签名锁定（21 CFR Part 11）',
                  style: AppTheme.caption.copyWith(height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('如何开始一次评估', style: AppTheme.title),
                const SizedBox(height: 8),
                Text(
                  '从「患者」页选择患者 → 进入患者详情 → 点击「新建创面评估」，按步骤完成拍照、量表与签名。',
                  style: AppTheme.caption.copyWith(height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
