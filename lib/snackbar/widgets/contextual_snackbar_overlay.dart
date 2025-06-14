import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/snackbar_cubit.dart';
import 'snackbar_item.dart';

class ContextualSnackbarOverlay extends StatelessWidget {
  const ContextualSnackbarOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SnackbarCubit, SnackbarState>(
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 8.0,
          left: 16.0,
          right: 16.0,
          child: Column(
            children: state.messages
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final message = entry.value;
                  final isLatest = index == 0;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..scale(isLatest ? 1.0 : 0.95)
                      ..translate(0.0, index * 2.0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isLatest ? 1.0 : 0.85,
                      child: SnackbarItem(
                        key: ValueKey(message.id),
                        message: message,
                        onDismiss: () => context.read<SnackbarCubit>().removeSnackbar(message.id),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        );
      },
    );
  }
}