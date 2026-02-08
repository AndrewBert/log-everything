import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/services/firestore_sync_service.dart';
import 'package:myapp/sync_status/cubit/sync_status_cubit.dart';
import 'package:myapp/dashboard_v2/widgets/sync_status_icon.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

import '../mocks.mocks.dart';

void main() {
  late MockFirestoreSyncService mockFirestoreSyncService;
  late StreamController<SyncStatus> syncStatusController;

  setUp(() {
    mockFirestoreSyncService = MockFirestoreSyncService();
    syncStatusController = StreamController<SyncStatus>.broadcast();
    when(mockFirestoreSyncService.syncStatusStream).thenAnswer((_) => syncStatusController.stream);
  });

  tearDown(() {
    syncStatusController.close();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            BlocProvider<SyncStatusCubit>(
              create: (_) => SyncStatusCubit(firestoreSyncService: mockFirestoreSyncService),
              child: const SyncStatusIcon(),
            ),
          ],
        ),
      ),
    );
  }

  group('SyncStatusIcon', () {
    testWidgets('Given idle status, When widget renders, Then no icon is shown', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // CP: Idle state should show nothing (SizedBox.shrink)
      expect(find.byKey(syncStatusIconKey), findsNothing);
    });

    testWidgets('Given syncing status, When status emits, Then cloud upload icon is shown', (tester) async {
      await tester.pumpWidget(buildWidget());

      syncStatusController.add(SyncStatus.syncing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byKey(syncStatusIconKey), findsOneWidget);
    });

    testWidgets('Given synced status, When status emits, Then cloud done icon is shown', (tester) async {
      await tester.pumpWidget(buildWidget());

      syncStatusController.add(SyncStatus.synced);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('Given error status, When status emits, Then cloud off icon is shown', (tester) async {
      await tester.pumpWidget(buildWidget());

      syncStatusController.add(SyncStatus.error);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('Given syncing then synced, When status transitions, Then icon updates', (tester) async {
      await tester.pumpWidget(buildWidget());

      // First syncing
      syncStatusController.add(SyncStatus.syncing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

      // Then synced
      syncStatusController.add(SyncStatus.synced);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('Given idle status returns, When status emits idle, Then icon disappears', (tester) async {
      await tester.pumpWidget(buildWidget());

      // Show synced first
      syncStatusController.add(SyncStatus.synced);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

      // Back to idle
      syncStatusController.add(SyncStatus.idle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(syncStatusIconKey), findsNothing);
    });
  });
}
