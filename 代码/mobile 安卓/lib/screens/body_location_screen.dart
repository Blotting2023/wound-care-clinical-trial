import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_client.dart';
import '../services/wound_service.dart';
import '../widgets/app_ui.dart';

/// 身体部位图形选择器：正面/背面切换，点击区域后选择具体部位，随后进入拍照。
class BodyLocationScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const BodyLocationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<BodyLocationScreen> createState() => _BodyLocationScreenState();
}

class _BodyLocationScreenState extends State<BodyLocationScreen>
    with SingleTickerProviderStateMixin {
  final WoundService _woundService = WoundService(apiClient: ApiClient.instance);
  late TabController _tabCtrl;
  String? _selectedZone;
  bool _creating = false;

  // 正面区域 → 可选具体部位
  final Map<String, List<String>> _frontZones = {
    '头面颈': ['头顶', '额部', '面部', '颈部前侧'],
    '胸腹': ['胸部', '腹部', '肋部'],
    '会阴': ['会阴'],
    '左上臂': ['左上臂前侧', '左上臂外侧'],
    '右上臂': ['右上臂前侧', '右上臂外侧'],
    '左前臂': ['左前臂前侧', '左前臂外侧'],
    '右前臂': ['右前臂前侧', '右前臂外侧'],
    '左手': ['左手背', '左掌心'],
    '右手': ['右手背', '右掌心'],
    '左大腿': ['左大腿前侧', '左大腿外侧', '左大腿内侧'],
    '右大腿': ['右大腿前侧', '右大腿外侧', '右大腿内侧'],
    '左小腿': ['左小腿前侧', '左小腿外侧', '左小腿内侧'],
    '右小腿': ['右小腿前侧', '右小腿外侧', '右小腿内侧'],
    '左足': ['左足背', '左足底'],
    '右足': ['右足背', '右足底'],
  };

  // 背面区域
  final Map<String, List<String>> _backZones = {
    '头颈后': ['枕部', '颈部后侧'],
    '背腰': ['背部', '腰部'],
    '骶尾部': ['骶尾部', '臀部'],
    '左上臂': ['左上臂后侧'],
    '右上臂': ['右上臂后侧'],
    '左前臂': ['左前臂后侧'],
    '右前臂': ['右前臂后侧'],
    '左手': ['左手背'],
    '右手': ['右手背'],
    '左大腿': ['左大腿后侧'],
    '右大腿': ['右大腿后侧'],
    '左小腿': ['左小腿后侧'],
    '右小腿': ['右小腿后侧'],
    '左足': ['左足跟'],
    '右足': ['右足跟'],
  };

  Map<String, List<String>> get _zones =>
      _tabCtrl.index == 0 ? _frontZones : _backZones;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() => _selectedZone = null);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLocationConfirmed(String location) async {
    if (_creating) return;
    setState(() => _creating = true);

    // 先创建新部位记录
    final result = await _woundService.createWound(
      patientId: widget.patientId,
      anatomicalLocation: location,
      onsetDate: DateTime.now(),
    );

    if (!mounted) return;
    setState(() => _creating = false);

    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建部位失败: ${result.message}')),
      );
      return;
    }

    final wound = result.data!;
    if (mounted) {
      Navigator.pushNamed(context, '/capture', arguments: {
        'patientId': widget.patientId,
        'woundId': wound.id,
        'patientName': widget.patientName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('选择部位'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.actionBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.actionBlue,
          tabs: const [
            Tab(text: '正面'),
            Tab(text: '背面'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBodyMap(isFront: true),
          _buildBodyMap(isFront: false),
        ],
      ),
    );
  }

  Widget _buildBodyMap({required bool isFront}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const StepIndicator(
            step: 1,
            total: 4,
            label: '选择部位 · 点击身体区域选择具体位置',
          ),
          const SizedBox(height: 20),
          // 身体示意图 + 可点击区域
          Center(
            child: SizedBox(
              width: 220,
              height: 420,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(220, 420),
                    painter: _BodyOutlinePainter(isFront: isFront),
                  ),
                  ..._buildZoneHitTargets(isFront),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 当前选中的区域提示
          if (_creating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.actionBlue)),
            )
          else if (_selectedZone != null) ...[
            Text('已选区域：$_selectedZone',
                style: AppTheme.caption.copyWith(
                    color: AppTheme.actionBlue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final loc in _zones[_selectedZone]!)
                  ScaleChip(
                    label: loc,
                    selected: false,
                    onTap: () => _onLocationConfirmed(loc),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildZoneHitTargets(bool isFront) {
    final zones = isFront ? _frontHitAreas : _backHitAreas;
    return zones.entries.map((e) {
      return Positioned(
        left: e.value.left,
        top: e.value.top,
        width: e.value.width,
        height: e.value.height,
        child: GestureDetector(
          onTap: () => setState(() => _selectedZone = e.key),
          child: Container(
            decoration: BoxDecoration(
              color: _selectedZone == e.key
                  ? AppTheme.actionBlue.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _selectedZone == e.key
                  ? Border.all(color: AppTheme.actionBlue, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: _selectedZone == e.key
                ? Text(e.key,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.actionBlue,
                        fontWeight: FontWeight.w600))
                : null,
          ),
        ),
      );
    }).toList();
  }

  // 正面热区 (x, y, w, h) 相对 220x420
  final Map<String, _Rect> _frontHitAreas = {
    '头面颈': _Rect(80, 10, 60, 50),
    '胸腹': _Rect(60, 70, 100, 90),
    '左上臂': _Rect(20, 80, 35, 70),
    '右上臂': _Rect(165, 80, 35, 70),
    '左前臂': _Rect(15, 155, 30, 65),
    '右前臂': _Rect(175, 155, 30, 65),
    '左手': _Rect(10, 225, 25, 30),
    '右手': _Rect(185, 225, 25, 30),
    '会阴': _Rect(85, 165, 50, 25),
    '左大腿': _Rect(55, 195, 50, 85),
    '右大腿': _Rect(115, 195, 50, 85),
    '左小腿': _Rect(60, 285, 40, 80),
    '右小腿': _Rect(120, 285, 40, 80),
    '左足': _Rect(62, 370, 35, 35),
    '右足': _Rect(122, 370, 35, 35),
  };

  // 背面热区
  final Map<String, _Rect> _backHitAreas = {
    '头颈后': _Rect(80, 10, 60, 50),
    '背腰': _Rect(60, 70, 100, 80),
    '骶尾部': _Rect(75, 155, 70, 35),
    '左上臂': _Rect(20, 80, 35, 70),
    '右上臂': _Rect(165, 80, 35, 70),
    '左前臂': _Rect(15, 155, 30, 65),
    '右前臂': _Rect(175, 155, 30, 65),
    '左手': _Rect(10, 225, 25, 30),
    '右手': _Rect(185, 225, 25, 30),
    '左大腿': _Rect(55, 195, 50, 85),
    '右大腿': _Rect(115, 195, 50, 85),
    '左小腿': _Rect(60, 285, 40, 80),
    '右小腿': _Rect(120, 285, 40, 80),
    '左足': _Rect(62, 370, 35, 35),
    '右足': _Rect(122, 370, 35, 35),
  };
}

class _Rect {
  final double left, top, width, height;
  _Rect(this.left, this.top, this.width, this.height);
}

/// 简笔人体轮廓画板。
class _BodyOutlinePainter extends CustomPainter {
  final bool isFront;
  _BodyOutlinePainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textHint.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..color = AppTheme.cardBackground
      ..style = PaintingStyle.fill;

    final c = size.width / 2;

    // 头
    final head = Rect.fromCenter(center: Offset(c, 35), width: 44, height: 52);
    canvas.drawOval(head, fill);
    canvas.drawOval(head, paint);

    // 颈
    canvas.drawLine(Offset(c, 61), Offset(c, 72), paint);

    // 躯干
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c, 130), width: 80, height: 110),
      const Radius.circular(16),
    );
    canvas.drawRRect(torso, fill);
    canvas.drawRRect(torso, paint);

    // 左臂
    _drawLimb(canvas, paint, fill,
        Offset(c - 48, 82), Offset(c - 75, 155), Offset(c - 78, 220), 14);
    // 右臂
    _drawLimb(canvas, paint, fill,
        Offset(c + 48, 82), Offset(c + 75, 155), Offset(c + 78, 220), 14);

    // 左腿
    _drawLimb(canvas, paint, fill,
        Offset(c - 22, 195), Offset(c - 25, 290), Offset(c - 25, 370), 18);
    // 右腿
    _drawLimb(canvas, paint, fill,
        Offset(c + 22, 195), Offset(c + 25, 290), Offset(c + 25, 370), 18);

    // 骨盆/髋提示线
    canvas.drawLine(Offset(c - 30, 190), Offset(c + 30, 190), paint);
  }

  void _drawLimb(Canvas canvas, Paint stroke, Paint fill,
      Offset top, Offset mid, Offset bottom, double width) {
    final path = Path();
    path.moveTo(top.dx - width / 2, top.dy);
    path.lineTo(top.dx + width / 2, top.dy);
    path.lineTo(mid.dx + width / 2 - 2, mid.dy);
    path.lineTo(bottom.dx + width / 2 - 3, bottom.dy);
    path.lineTo(bottom.dx - width / 2 + 3, bottom.dy);
    path.lineTo(mid.dx - width / 2 + 2, mid.dy);
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
