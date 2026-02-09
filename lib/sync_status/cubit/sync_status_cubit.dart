import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/services/firestore_sync_service.dart';

// CP: Lightweight cubit that subscribes to FirestoreSyncService sync status stream.
// Provided at app level so any page can show sync status.
class SyncStatusCubit extends Cubit<SyncStatus> {
  final FirestoreSyncService _firestoreSyncService;
  StreamSubscription<SyncStatus>? _subscription;

  SyncStatusCubit({
    required FirestoreSyncService firestoreSyncService,
  })  : _firestoreSyncService = firestoreSyncService,
        super(SyncStatus.idle) {
    _subscription = _firestoreSyncService.syncStatusStream.listen((status) {
      if (!isClosed) {
        emit(status);
      }
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
