import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/snackbar_cubit.dart';
import '../models/snackbar_message.dart';
import 'snackbar_item.dart';

class ContextualSnackbarOverlay extends StatelessWidget {
  const ContextualSnackbarOverlay({
    super.key,
    this.contextFilter = SnackbarContext.global,
    this.topOffset = 0,
  });

  final SnackbarContext contextFilter;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SnackbarCubit, SnackbarState>(
      builder: (context, state) {
        // Show only the current message if it matches the context filter
        final currentMessage = state.currentMessage;
        if (currentMessage == null || 
            (currentMessage.context != contextFilter && currentMessage.context != SnackbarContext.global)) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: topOffset,
          left: 16.0,
          right: 16.0,
          child: SnackbarItem(
            key: ValueKey(currentMessage.id),
            message: currentMessage,
            onDismiss: () => context.read<SnackbarCubit>().removeSnackbar(currentMessage.id),
          ),
        );
      },
    );
  }
}
