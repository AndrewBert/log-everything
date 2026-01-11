import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/device_id_service.dart';
import 'package:myapp/services/snapshot_service.dart';
import 'package:myapp/services/vector_store_service.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/settings/widgets/account_section.dart';
import 'package:myapp/settings/widgets/general_section.dart';
import 'package:myapp/settings/widgets/recovery_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(
        authService: GetIt.instance<AuthService>(),
        entryRepository: GetIt.instance<EntryRepository>(),
        deviceIdService: GetIt.instance<DeviceIdService>(),
        snapshotService: GetIt.instance<SnapshotService>(),
        vectorStoreService: GetIt.instance<VectorStoreService>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: MultiBlocListener(
          listeners: [
            // CP: Listen for error messages
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (prev, current) => prev.errorMessage != current.errorMessage && current.errorMessage != null,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
                context.read<SettingsCubit>().clearError();
              },
            ),
            // CP: Listen for recovery info to show recovery dialog
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (prev, current) => prev.recoveryInfo != current.recoveryInfo && current.recoveryInfo != null,
              listener: (context, state) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => BlocProvider.value(
                    value: context.read<SettingsCubit>(),
                    child: RecoveryDialog(recoveryInfo: state.recoveryInfo!),
                  ),
                );
              },
            ),
          ],
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                children: const [
                  AccountSection(),
                  Divider(height: 32),
                  GeneralSection(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
