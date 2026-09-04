import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/photo_metadata.dart';
import '../services/cos_uploader.dart';
import '../services/demo_image_generator.dart';
import '../utils/photo_time.dart';
import '../widgets/app_ui.dart';
import '../widgets/calibration_overlay.dart';

class AssessmentCaptureScreen extends StatefulWidget {
  final String patientId;
  final String woundId;
  final String? patientName;
  const AssessmentCaptureScreen({
    super.key,
    required this.patientId,
    required this.woundId,
    this.patientName,
  });

  @override
  State<AssessmentCaptureScreen> createState() => _AssessmentCaptureScreenState();
}

class _AssessmentCaptureScreenState extends State<AssessmentCaptureScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  bool _capturing = false;

  /// On macOS / iOS simulator (and in demo mode) the camera plugin is
  /// unavailable, so we offer a "simulate capture" flow that generates a
  /// synthetic wound photo.
  bool get _useDemoCapture =>
      ApiConfig.demoMode && (Platform.isMacOS || Platform.isIOS);

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_useDemoCapture) {
      // No camera on macOS: mark ready immediately.
      _isReady = true;
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    final cam = _cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first);
    _controller = CameraController(cam, ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    await _controller!.lockCaptureOrientation();
    await _controller!.setFlashMode(FlashMode.off);
    // Lock exposure if supported (white balance control is not exposed
    // in camera 0.11+).
    try {
      await _controller!.setExposureMode(ExposureMode.locked);
    } catch (_) {}
    if (mounted) setState(() => _isReady = true);
  }

  Future<void> _capture() async {
    if (!_isReady || _capturing) return;
    setState(() => _capturing = true);
    try {
      final dir = await getTemporaryDirectory();
      String imagePath;
      if (_useDemoCapture) {
        // Demo mode on macOS: generate a synthetic wound photo.
        imagePath = await DemoImageGenerator.generateWoundImage(dir.path);
      } else {
        final image = await _controller!.takePicture();
        // Compress
        final compressed = await FlutterImageCompress.compressAndGetFile(
          image.path,
          '${dir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );
        imagePath = compressed?.path ?? image.path;
      }
      // 给 demo 一个固定 assessmentId 以便 review 页拿到 photo metadata
      final assessmentId = 'asmt_pending_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        await _uploadAndGotoReview(
          imagePath: imagePath,
          assessmentId: assessmentId,
          recordTime: DateTime.now(),
          photoTimeSource: 'now',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
        setState(() => _capturing = false);
      }
    }
  }

  /// 从系统相册导入已有照片。读取 EXIF 拍摄时间，作为评估 createdAt。
  Future<void> _importFromGallery() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        // 不压缩（避免 image_picker 把 EXIF 抹掉）
        imageQuality: 100,
      );
      if (picked == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      // 复制到 app tmp 目录，避免外部相册路径下次打开失效
      final dir = await getTemporaryDirectory();
      final ext = picked.name.contains('.')
          ? picked.name.substring(picked.name.lastIndexOf('.'))
          : '.jpg';
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final dest = '${dir.path}/imported_$stamp$ext';
      await File(picked.path).copy(dest);

      // 读 EXIF 拍摄时间
      final time = await readPhotoTakenAt(dest);
      final assessmentId = 'asmt_pending_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        await _uploadAndGotoReview(
          imagePath: dest,
          assessmentId: assessmentId,
          recordTime: time?.takenAt ?? DateTime.now(),
          photoTimeSource: time?.source,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
        setState(() => _capturing = false);
      }
    }
  }

  /// GCP W3.1 — 算 SHA256 + 读 EXIF + 模拟 COS 上传，然后把 metadata 一并
  /// 传给 review 页。demo 阶段 COS 上传走本地模拟，真实阶段把 CosUploader
  /// 替换成腾讯云 SDK 即可。
  Future<void> _uploadAndGotoReview({
    required String imagePath,
    required String assessmentId,
    required DateTime recordTime,
    String? photoTimeSource,
  }) async {
    try {
      final metadata = await CosUploader.I.uploadPhoto(
        localPath: imagePath,
        assessmentId: assessmentId,
        capturedBy: 'demo-nurse-01',
        capturedByRole: 'CRC',
      );
      if (!mounted) return;
      _gotoReview(
        imagePath: imagePath,
        recordTime: recordTime,
        photoTimeSource: photoTimeSource,
        photoMetadata: metadata,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('照片源数据落库失败: $e')));
        // 不阻断流程，让 review 页仍能打开（无 metadata）
        if (mounted) {
          _gotoReview(
            imagePath: imagePath,
            recordTime: recordTime,
            photoTimeSource: photoTimeSource,
          );
        }
      }
    }
  }

  void _gotoReview({
    required String imagePath,
    required DateTime recordTime,
    String? photoTimeSource,
    PhotoMetadata? photoMetadata,
  }) {
    Navigator.pushReplacementNamed(context, '/review', arguments: {
      'patientId': widget.patientId,
      'woundId': widget.woundId,
      'imagePath': imagePath,
      'recordTime': recordTime.toIso8601String(),
      'photoTimeSource': photoTimeSource ?? 'now',
      if (photoMetadata != null) 'photoMetadata': photoMetadata.toJson(),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) _controller?.dispose();
    if (state == AppLifecycleState.resumed) _initCamera();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_useDemoCapture) return _buildDemoCapture();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          CalibrationOverlay(),
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: Center(
              child: FloatingActionButton.large(
                heroTag: 'capture',
                onPressed: _capturing ? null : _capture,
                child: _capturing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.camera, size: 40),
              ),
            ),
          ),
          Positioned(
            bottom: 80, right: 24,
            child: FloatingActionButton.small(
              heroTag: 'import',
              onPressed: _capturing ? null : _importFromGallery,
              tooltip: '导入照片',
              child: const Icon(Icons.photo_library_rounded, size: 22),
            ),
          ),
          Positioned(
            top: 48, left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCapture() {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(title: const Text('拍照 + AI 测量')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StepIndicator(
                  step: 1, total: 4, label: '第 1 步 · 拍照测量'),
              const SizedBox(height: 32),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 64, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              const Text('模拟拍照（演示模式）',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '桌面端 / 模拟器无相机，演示模式将自动生成\n一张含校准卡的模拟伤口照片，随后进入\nAI 分析 → 测量核对 → 量表 → 签名流程。',
                textAlign: TextAlign.center,
                style: AppTheme.caption,
              ),
              const SizedBox(height: 8),
              Text('拍摄建议：光线充足 · 垂直拍摄 · 距离 15–20 cm',
                  style: AppTheme.micro),
              const SizedBox(height: 32),
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('模拟拍照'),
                  onPressed: _capturing ? null : _capture,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('从相册导入照片'),
                  onPressed: _capturing ? null : _importFromGallery,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '导入时会读取照片 EXIF 拍摄时间作为记录时间。',
                textAlign: TextAlign.center,
                style: AppTheme.micro.copyWith(color: AppTheme.textHint),
              ),
              if (_capturing) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: AppTheme.actionBlue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
