import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/assessment.dart';
import 'assessment_service.dart';
import 'image_service.dart';
import 'offline_db.dart';
import 'api_client.dart';

/// Offline sync service: queues pending assessments for upload when
/// network connectivity is restored.
///
/// Demo note: with the demo backend, sync is a no-op because drafts are
/// "uploaded" instantly; the queue still works for real deployments.
class SyncService {
  final AssessmentService _assessmentService;
  final ImageService _imageService;
  final OfflineDb _offlineDb;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;
  bool _isOnline = true;

  /// Callback when sync state changes.
  void Function(bool isSyncing, int pendingCount)? onSyncStateChanged;

  SyncService({
    AssessmentService? assessmentService,
    ImageService? imageService,
    OfflineDb? offlineDb,
    Connectivity? connectivity,
  })  : _assessmentService =
            assessmentService ?? AssessmentService(apiClient: ApiClient.instance),
        _imageService = imageService ?? ImageService(apiClient: ApiClient.instance),
        _offlineDb = offlineDb ?? OfflineDb(),
        _connectivity = connectivity ?? Connectivity();

  /// Start listening to connectivity changes.
  void startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (wasOffline && _isOnline) {
        syncPending();
      }
    });
  }

  /// Stop listening.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Whether a sync is in progress.
  bool get isSyncing => _isSyncing;

  /// Queue an assessment for later sync and save to local DB.
  Future<void> queueForSync(Assessment assessment,
      {List<String>? imagePaths}) async {
    await _offlineDb.insertDraft(assessment, imagePaths: imagePaths);
    _notifyStateChanged();
  }

  /// Attempt to sync all pending draft assessments.
  Future<void> syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _notifyStateChanged();

    try {
      final drafts = await _offlineDb.getAllDrafts();
      for (final draft in drafts) {
        try {
          await _syncOne(draft);
          await _offlineDb.deleteDraft(draft.id);
        } catch (e) {
          // Keep the draft for a later retry / manual resolution.
        }
      }
    } finally {
      _isSyncing = false;
      _notifyStateChanged();
    }
  }

  Future<void> _syncOne(Assessment draft) async {
    // 1. Upload images first
    final imagePaths = await _offlineDb.getDraftImagePaths(draft.id);
    if (imagePaths != null && imagePaths.isNotEmpty) {
      for (final path in imagePaths) {
        final result = await _imageService.uploadImage(
          assessmentId: draft.id,
          filePath: path,
          imageType: 'woundCapture',
        );
        if (!result.success) {
          throw Exception('Image upload failed: ${result.message}');
        }
      }
    }

    // 2. POST assessment
    final result = await _assessmentService.confirmAssessment(draft);
    if (!result.success) {
      throw Exception('Assessment sync failed: ${result.message}');
    }
  }

  /// Get the count of pending drafts.
  Future<int> getPendingCount() async {
    return _offlineDb.countDrafts();
  }

  /// Clear all offline data (on logout).
  Future<void> clearAll() async {
    await _offlineDb.clearAll();
    _notifyStateChanged();
  }

  void _notifyStateChanged() async {
    final pending = await _offlineDb.countDrafts();
    onSyncStateChanged?.call(_isSyncing, pending);
  }
}
