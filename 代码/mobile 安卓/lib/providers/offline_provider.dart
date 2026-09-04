import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class OfflineProvider extends ChangeNotifier {
  final SyncService _sync;

  int _pendingCount = 0;
  bool _isSyncing = false;

  OfflineProvider({SyncService? sync})
      : _sync = sync ?? SyncService() {
    _sync.onSyncStateChanged = (syncing, pending) {
      _isSyncing = syncing;
      _pendingCount = pending;
      notifyListeners();
    };
  }

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  Future<void> updatePendingCount() async {
    _pendingCount = await _sync.getPendingCount();
    notifyListeners();
  }

  Future<void> syncAll() async {
    await _sync.syncPending();
    _pendingCount = await _sync.getPendingCount();
    notifyListeners();
  }
}
