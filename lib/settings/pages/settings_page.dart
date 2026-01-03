import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/settings/widgets/account_section.dart';
import 'package:myapp/settings/widgets/general_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(authService: GetIt.instance<AuthService>()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (prev, current) => prev.errorMessage != current.errorMessage && current.errorMessage != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
            context.read<SettingsCubit>().clearError();
          },
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
