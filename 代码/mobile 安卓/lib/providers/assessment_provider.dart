import 'package:flutter/material.dart';
import '../models/assessment.dart';
import '../models/request_models.dart';
import '../services/api_client.dart';
import '../services/assessment_service.dart';

/// Assessment data provider. Holds the current draft and the history list
/// for a wound, delegating to [AssessmentService].
class AssessmentProvider extends ChangeNotifier {
  final AssessmentService _assessmentService;

  List<Assessment> _history = [];
  Assessment? _current;
  bool _isLoading = false;

  AssessmentProvider({AssessmentService? assessmentService})
      : _assessmentService =
            assessmentService ?? AssessmentService(apiClient: ApiClient.instance);

  List<Assessment> get history => List.unmodifiable(_history);
  Assessment? get current => _current;
  bool get isLoading => _isLoading;

  /// Load the assessment timeline for a wound.
  Future<void> loadHistory(String woundId) async {
    _isLoading = true;
    notifyListeners();
    final result = await _assessmentService.getAssessments(woundId);
    _history = result.success ? (result.data ?? []) : [];
    _isLoading = false;
    notifyListeners();
  }

  /// Create a new draft assessment for a wound.
  /// [recordTime]: 来自导入照片的 EXIF 时间；为 null 则用后端"现在"。
  Future<Assessment?> createDraft(
    String patientId,
    String woundId,
    String? subjectId, {
    DateTime? recordTime,
  }) async {
    final result = await _assessmentService.createAssessment(
      patientId: patientId,
      woundId: woundId,
      clinicianId: 'demo-nurse-01',
      clinicianName: '演示护士',
      recordTime: recordTime,
    );
    if (!result.success) return null;
    _current = result.data;
    notifyListeners();
    return _current;
  }

  /// Run AI analysis on the current assessment (demo: returns fake values).
  Future<void> saveAiResults(String id, String imageUrl) async {
    final result = await _assessmentService.submitForAnalysis(
      assessmentId: id,
      imageUrl: imageUrl,
    );
    if (result.success) {
      _current = result.data;
      notifyListeners();
    }
  }

  /// Confirm the assessment with clinician values.
  Future<void> confirm(String id, ClinicianConfirmRequest request) async {
    final current = _current;
    if (current == null) return;
    final result = await _assessmentService.confirmAssessment(
      current.copyWith(
        finalAreaCm2: request.finalAreaCm2,
        finalLengthCm: request.finalLengthCm,
        finalWidthCm: request.finalWidthCm,
        finalPolygonJson: request.finalPolygonJson,
        finalTissuePercentages: request.finalTissuePercentages,
        nrsPainScore: request.nrsPainScore,
        vssVascularity: request.vssVascularity,
        vssPigmentation: request.vssPigmentation,
        vssPliability: request.vssPliability,
        vssHeight: request.vssHeight,
        vssTotal: request.vssTotal,
        notes: request.manualOverrideReason,
        // W3 fields
        concomitantMedications: request.concomitantMedications,
        concomitantDiseases: request.concomitantDiseases,
        aeRefs: request.aeRefs,
        photoMetadataSnapshot: request.photoMetadataSnapshot,
      ),
    );
    if (result.success) {
      _current = result.data;
      notifyListeners();
    }
  }

  /// Submit the assessment for electronic signature.
  Future<void> submit(String id) async {
    final result = await _assessmentService.submitForSignature(id);
    if (result.success) {
      _current = result.data;
      notifyListeners();
    }
  }

  /// Lock the assessment with a signature PIN.
  Future<void> lock(String id, String pin, String meaning) async {
    final result = await _assessmentService.lockAssessment(
      assessmentId: id,
      pin: pin,
      signOffMethod: 'pin',
    );
    if (result.success) {
      _current = result.data;
      notifyListeners();
    } else {
      throw Exception(result.message);
    }
  }

  /// GCP W3.1 — 读取冻结的照片源数据（用于评估详情页"下载原始"）。
  Future<Map<String, dynamic>?> loadPhotoMetadata(String assessmentId) async {
    final r = await _assessmentService.getPhotoMetadata(assessmentId);
    return r.success ? r.data : null;
  }

  /// GCP W3.2 — PI 必签的 CRF 完成声明（PIN 二次鉴别）。
  Future<void> declareCrfComplete({
    required String assessmentId,
    required String pin,
  }) async {
    final r = await _assessmentService.declareCrfComplete(
      assessmentId: assessmentId,
      pin: pin,
      operatorId: 'demo-physician-01',
      operatorName: '演示医师',
    );
    if (r.success) {
      _current = r.data;
      notifyListeners();
    } else {
      throw Exception(r.message);
    }
  }
}
