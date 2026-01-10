import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/device_id_service.dart';
import 'package:myapp/services/snapshot_service.dart';
import 'package:myapp/services/vector_store_service.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/utils/logger.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final AuthService _authService;
  final EntryRepository _entryRepository;
  final DeviceIdService _deviceIdService;
  final SnapshotService _snapshotService;
  final VectorStoreService _vectorStoreService;
  StreamSubscription<AuthUser?>? _authSubscription;

  // CP: Track previous user ID to distinguish "app started with no user" from "user signed out"
  // Only clear local data when transitioning FROM signed-in TO signed-out
  String? _previousUserId;

  // CP: Track entry count before sign-in to detect data loss
  int _entryCountBeforeSignIn = 0;

  // CP: Flag to indicate a sign-in is pending and we should check for data loss after merge
  bool _pendingDataLossCheck = false;

  SettingsCubit({
    required AuthService authService,
    required EntryRepository entryRepository,
    required DeviceIdService deviceIdService,
    required SnapshotService snapshotService,
    required VectorStoreService vectorStoreService,
  })  : _authService = authService,
        _entryRepository = entryRepository,
        _deviceIdService = deviceIdService,
        _snapshotService = snapshotService,
        _vectorStoreService = vectorStoreService,
        super(const SettingsState()) {
    _init();
  }

  void _init() {
    emit(state.copyWith(isLoading: true));

    // CP: Subscribe to auth state changes
    _authSubscription = _authService.authStateChanges.listen(
      (user) async {
        // CP: Handle cloud sync on auth state change
        if (user != null) {
          await _entryRepository.onUserSignedIn(user.uid);
          _previousUserId = user.uid;

          // CP: Check for data loss AFTER cloud merge completes (not before)
          if (_pendingDataLossCheck) {
            _pendingDataLossCheck = false;
            await _checkForDataLossAndOfferRecovery();
          }
        } else {
          // CP: Only clear data if transitioning FROM signed-in state
          // This prevents data loss when app starts with no signed-in user
          if (_previousUserId != null) {
            await _entryRepository.onUserSignedOut();
          }
          _previousUserId = null;
        }
        emit(state.copyWith(
          currentUser: user,
          clearUser: user == null,
          isLoading: false,
        ));
      },
      onError: (error) {
        AppLogger.error('Auth state stream error', error: error);
        emit(state.copyWith(isLoading: false));
      },
    );

    // CP: Set initial user state and trigger sync if already signed in
    final user = _authService.currentUser;
    if (user != null) {
      _entryRepository.onUserSignedIn(user.uid);
      _previousUserId = user.uid;
    }
    emit(state.copyWith(
      currentUser: user,
      clearUser: user == null,
      isLoading: false,
    ));
  }

  Future<void> signInWithGoogle() => _performSignIn(
        signInMethod: _authService.signInWithGoogle,
        providerName: 'Google',
      );

  Future<void> signInWithApple() => _performSignIn(
        signInMethod: _authService.signInWithApple,
        providerName: 'Apple',
      );

  /// CP: Common sign-in logic for all providers.
  Future<void> _performSignIn({
    required Future<void> Function() signInMethod,
    required String providerName,
  }) async {
    try {
      emit(state.copyWith(isSigningIn: true, clearError: true));

      // CP: Create pre-sign-in snapshot as failsafe
      await _createPreSignInSnapshot();

      // CP: Set flag so auth listener checks for data loss after merge completes
      _pendingDataLossCheck = true;

      await signInMethod();
      emit(state.copyWith(isSigningIn: false));
    } on AuthCancelledException {
      _pendingDataLossCheck = false;
      emit(state.copyWith(isSigningIn: false));
      AppLogger.info('User cancelled $providerName sign in');
    } on AuthException catch (e) {
      _pendingDataLossCheck = false;
      emit(state.copyWith(isSigningIn: false, errorMessage: e.message));
    } catch (e) {
      _pendingDataLossCheck = false;
      AppLogger.error('Unexpected $providerName sign in error', error: e);
      emit(state.copyWith(isSigningIn: false, errorMessage: 'An unexpected error occurred'));
    }
  }

  /// CP: Creates a snapshot of local data before sign-in as a failsafe against data loss.
  Future<void> _createPreSignInSnapshot() async {
    try {
      final entries = _entryRepository.currentEntries;
      final categories = _entryRepository.currentCategories;

      // CP: Track entry count to detect data loss after sign-in
      _entryCountBeforeSignIn = entries.length;

      // CP: Skip snapshot if user has no data to backup
      if (entries.isEmpty && categories.isEmpty) {
        AppLogger.info('[SettingsCubit] No local data to snapshot, skipping');
        return;
      }

      final deviceId = await _deviceIdService.getDeviceId();
      final vectorStoreId = _vectorStoreService.getVectorStoreId();
      final monthlyLogFileIds = _vectorStoreService.getMonthlyLogFileIds();

      await _snapshotService.createSnapshot(
        deviceId: deviceId,
        entries: entries,
        categories: categories,
        vectorStoreId: vectorStoreId,
        monthlyLogFileIds: monthlyLogFileIds,
      );

      AppLogger.info('[SettingsCubit] Pre-sign-in snapshot created: ${entries.length} entries, ${categories.length} categories');
    } catch (e) {
      // CP: Don't block sign-in if snapshot fails - log and continue
      AppLogger.error('[SettingsCubit] Failed to create pre-sign-in snapshot', error: e);
    }
  }

  /// CP: Checks if data was lost during sign-in and offers recovery if a snapshot exists.
  Future<void> _checkForDataLossAndOfferRecovery() async {
    try {
      final currentEntryCount = _entryRepository.currentEntries.length;

      // CP: Data loss detected if user had entries before but has none/fewer now
      final dataLossDetected = _entryCountBeforeSignIn > 0 && currentEntryCount == 0;

      if (!dataLossDetected) {
        // CP: Sign-in succeeded without data loss - schedule snapshot deletion
        AppLogger.info('[SettingsCubit] Sign-in successful, no data loss detected');
        await _scheduleSnapshotCleanup();
        return;
      }

      // CP: Data loss detected - check for recovery snapshot
      AppLogger.warn('[SettingsCubit] Potential data loss detected! Had $_entryCountBeforeSignIn entries, now have $currentEntryCount');

      final deviceId = await _deviceIdService.getDeviceId();
      final snapshot = await _snapshotService.fetchSnapshot(deviceId);

      if (snapshot != null && snapshot.entryCount > 0) {
        AppLogger.info('[SettingsCubit] Recovery snapshot found with ${snapshot.entryCount} entries');
        emit(state.copyWith(
          recoveryInfo: RecoveryInfo(
            entryCount: snapshot.entryCount,
            categoryCount: snapshot.categoryCount,
            snapshotCreatedAt: snapshot.createdAt,
          ),
        ));
      }
    } catch (e) {
      AppLogger.error('[SettingsCubit] Error checking for data loss', error: e);
    }
  }

  /// CP: Schedule snapshot deletion after successful sign-in (7 day retention).
  Future<void> _scheduleSnapshotCleanup() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final hasSnapshot = await _snapshotService.hasValidSnapshot(deviceId);

      if (hasSnapshot) {
        await _snapshotService.scheduleSnapshotDeletion(deviceId, const Duration(days: 7));
        AppLogger.info('[SettingsCubit] Snapshot scheduled for deletion in 7 days');
      }
    } catch (e) {
      AppLogger.error('[SettingsCubit] Error scheduling snapshot cleanup', error: e);
    }
  }

  /// CP: Confirms recovery from snapshot - restores entries, categories, and vector store info.
  Future<void> confirmRecovery() async {
    try {
      emit(state.copyWith(isRecovering: true));

      final deviceId = await _deviceIdService.getDeviceId();
      final snapshot = await _snapshotService.fetchSnapshot(deviceId);

      if (snapshot == null) {
        AppLogger.error('[SettingsCubit] Recovery failed: snapshot not found');
        emit(state.copyWith(isRecovering: false, clearRecovery: true, errorMessage: 'Recovery snapshot not found'));
        return;
      }

      // CP: Restore entries and categories via repository
      if (snapshot.entries.isNotEmpty) {
        await _entryRepository.addEntryObjects(snapshot.entries);
      }
      if (snapshot.categories.isNotEmpty) {
        await _entryRepository.addCategoryObjects(snapshot.categories);
      }

      // CP: Restore vector store info
      await _vectorStoreService.restoreFromSnapshot(
        snapshot.vectorStoreId,
        snapshot.monthlyLogFileIds,
      );

      // CP: Delete snapshot after successful recovery
      await _snapshotService.deleteSnapshot(deviceId);

      AppLogger.info('[SettingsCubit] Recovery complete: ${snapshot.entryCount} entries restored');
      emit(state.copyWith(isRecovering: false, clearRecovery: true));
    } catch (e) {
      AppLogger.error('[SettingsCubit] Recovery failed', error: e);
      emit(state.copyWith(isRecovering: false, errorMessage: 'Failed to recover data'));
    }
  }

  /// CP: Dismisses the recovery prompt without restoring data.
  void dismissRecovery() {
    emit(state.copyWith(clearRecovery: true));
  }

  /// CP: Manually checks for and offers recovery from a snapshot (for Settings UI).
  Future<void> checkForManualRecovery() async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final snapshot = await _snapshotService.fetchSnapshot(deviceId);

      if (snapshot != null && snapshot.entryCount > 0) {
        emit(state.copyWith(
          recoveryInfo: RecoveryInfo(
            entryCount: snapshot.entryCount,
            categoryCount: snapshot.categoryCount,
            snapshotCreatedAt: snapshot.createdAt,
          ),
        ));
      } else {
        emit(state.copyWith(errorMessage: 'No recovery backup found'));
      }
    } catch (e) {
      AppLogger.error('[SettingsCubit] Error checking for manual recovery', error: e);
      emit(state.copyWith(errorMessage: 'Failed to check for backup'));
    }
  }

  Future<void> signOut() async {
    try {
      emit(state.copyWith(isSigningOut: true, clearError: true));
      await _authService.signOut();
      emit(state.copyWith(isSigningOut: false));
    } on AuthException catch (e) {
      emit(state.copyWith(isSigningOut: false, errorMessage: e.message));
    } catch (e) {
      AppLogger.error('Unexpected sign out error', error: e);
      emit(state.copyWith(isSigningOut: false, errorMessage: 'Sign out failed'));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
