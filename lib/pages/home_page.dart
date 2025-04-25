import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/cubit/voice_input_cubit.dart';
import 'package:myapp/utils/logger.dart';
import 'dart:async'; // Import async for Timer
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus

import '../cubit/entry_cubit.dart';
import '../cubit/home_screen_cubit.dart';
import '../cubit/home_screen_state.dart';
import '../entry.dart';
import '../utils/category_colors.dart';
import '../widgets/entries_list.dart';
import '../widgets/filter_section.dart';
import '../widgets/input_area.dart';
import '../dialogs/edit_entry_dialog.dart';
import '../dialogs/manage_categories_dialog.dart';
import '../dialogs/change_category_dialog.dart';
import '../dialogs/help_dialog.dart';
import '../dialogs/whats_new_dialog.dart';
import '../dialogs/delete_category_confirmation_dialog.dart';
import '../dialogs/edit_category_dialog.dart';

// Convert HomePage to StatelessWidget
class HomePage extends StatelessWidget {
  HomePage({super.key});

  // Move formatter here
  final DateFormat _timeFormatter = DateFormat('HH:mm');

  // Move methods from _HomePageState directly into HomePage

  void _showFloatingSnackBar(
    BuildContext targetContext, {
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.hideCurrentSnackBar();

    final keyboardVisible = MediaQuery.of(targetContext).viewInsets.bottom > 0;
    final bottomPadding = MediaQuery.of(targetContext).padding.bottom;
    final double bottomMargin =
        keyboardVisible
            ? MediaQuery.of(targetContext).viewInsets.bottom + 8.0
            : bottomPadding + 80.0;

    messenger.showSnackBar(
      SnackBar(
        content: content,
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16.0, right: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  Future<void> _showWhatsNewDialog(
    BuildContext context, [
    String? version,
  ]) async {
    // Need context passed in now
    String currentVersion = version ?? '';
    if (currentVersion.isEmpty) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      } catch (e, stackTrace) {
        AppLogger.error(
          'Error getting package info for What\'s New dialog: $e',
          stackTrace: stackTrace,
        );
        // Check context is still valid if async gap occurred
        if (!context.mounted) return;
        _showFloatingSnackBar(
          context,
          content: const Text('Could not load version info.'),
          backgroundColor: Colors.redAccent,
        );
        return;
      }
    }

    String displayVersion = currentVersion;
    final versionMatch = RegExp(
      r'v([0-9]+\.[0-9]+\.[0-9]+)',
    ).firstMatch(currentVersion);
    if (versionMatch != null) {
      displayVersion = versionMatch.group(1) ?? currentVersion;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder:
          (dialogContext) => WhatsNewDialog(currentVersion: displayVersion),
    );
  }

  void _handleInput(BuildContext context, String currentText) {
    // Need context passed in now
    final voiceCubit = context.read<VoiceInputCubit>();
    final entryCubit = context.read<EntryCubit>();

    if (voiceCubit.state.isRecording) {
      AppLogger.info(
        'Send tapped during recording. Stopping and combining text with transcription.',
      );
      HapticFeedback.mediumImpact();
      voiceCubit.stopRecordingAndCombine(currentText);
      _showProcessingSnackbar(context, 'Processing voice entry...');
      return;
    }

    if (currentText.isNotEmpty) {
      entryCubit.addEntry(currentText);
      _showProcessingSnackbar(context, 'Processing text entry...');
    }
  }

  void _showProcessingSnackbar(BuildContext context, String message) {
    // Need context passed in now
    _showFloatingSnackBar(
      context,
      content: Row(
        children: [
          const Icon(
            Icons.pending_actions_outlined,
            size: 18,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(message),
        ],
      ),
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<bool> _showDeleteCategoryConfirmationDialog(
    BuildContext context,
    String category,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return DeleteCategoryConfirmationDialog(category: category);
          },
        ) ??
        false;
  }

  void _showManageCategoriesDialog(BuildContext context) {
    // Need context passed in now
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ManageCategoriesDialog(
          onShowEditCategoryDialog:
              (ctx, oldName) => _showEditCategoryDialog(ctx, oldName),
          onShowDeleteCategoryConfirmationDialog:
              (ctx, cat) => _showDeleteCategoryConfirmationDialog(ctx, cat),
        );
      },
    );
  }

  Future<String?> _showEditCategoryDialog(
    BuildContext context,
    String oldCategoryName,
  ) async {
    return await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return EditCategoryDialog(oldCategoryName: oldCategoryName);
      },
    );
  }

  Future<void> _showEditEntryDialog(
    BuildContext context,
    Entry originalEntry,
  ) async {
    // Need context passed in now
    final Entry? updatedEntry = await showDialog<Entry?>(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: BlocProvider.of<EntryCubit>(context),
          child: EditEntryDialog(originalEntry: originalEntry),
        );
      },
    );

    if (updatedEntry != null && context.mounted) {
      _showFloatingSnackBar(
        context,
        content: const Text('Entry updated'),
        duration: const Duration(seconds: 1),
      );
    }
  }

  Future<void> _showChangeCategoryDialog(
    BuildContext context,
    Entry entry,
  ) async {
    // Need context passed in now
    final entryCubit = context.read<EntryCubit>();
    final availableCategories = List<String>.from(entryCubit.state.categories)
      ..sort();
    String? selectedCategory = entry.category;

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    final String? newCategory = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return ChangeCategoryDialog(
          currentCategory: selectedCategory,
          availableCategories: availableCategories,
        );
      },
    );

    if (newCategory != null && newCategory != entry.category) {
      final updatedEntry = entry.copyWith(category: newCategory);
      entryCubit.updateEntry(entry, updatedEntry);
      if (context.mounted) {
        _showFloatingSnackBar(
          context,
          content: Text('Category changed to "$newCategory"'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _showHelpDialog(BuildContext context) {
    // Need context passed in now
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return HelpDialog(
          onShowWhatsNewPressed: () => _showWhatsNewDialog(context),
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  Color _getCategoryColor(String category) {
    return CategoryColors.getColorForCategory(category);
  }

  void _handleDeleteEntry(BuildContext context, Entry entry) {
    // Need context passed in now
    final entryToDelete = entry;
    context.read<EntryCubit>().deleteEntry(entryToDelete);
    // Check context is still valid
    if (context.mounted) {
      _showFloatingSnackBar(
        context,
        content: const Text('Entry deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Check context again inside async callback
            if (context.mounted) {
              context.read<EntryCubit>().addEntryObject(entryToDelete);
            }
          },
        ),
      );
    }
  }

  // Move build method here
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color? defaultTitleColor =
        Theme.of(context).appBarTheme.titleTextStyle?.color;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            context.read<HomeScreenCubit>().incrementTitleTap();
          },
          child: RichText(
            text: TextSpan(
              style:
                  Theme.of(context).appBarTheme.titleTextStyle ??
                  Theme.of(context).textTheme.titleLarge,
              children: <TextSpan>[
                TextSpan(
                  text: 'Log',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' Splitter',
                  style: TextStyle(color: defaultTitleColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          BlocBuilder<HomeScreenCubit, HomeScreenState>(
            buildWhen: (prev, current) => prev.appVersion != current.appVersion,
            builder: (context, state) {
              if (state.appVersion.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: Text(
                      state.appVersion,
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help / About',
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () => _showManageCategoriesDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<HomeScreenCubit, HomeScreenState>(
            listenWhen:
                (prev, current) =>
                    !prev.showWhatsNewDialog && current.showWhatsNewDialog,
            listener: (context, state) async {
              // Pass context here
              await _showWhatsNewDialog(context, state.appVersion);
              if (context.mounted) {
                context.read<HomeScreenCubit>().markWhatsNewShown();
              }
            },
          ),
          BlocListener<HomeScreenCubit, HomeScreenState>(
            listenWhen:
                (prev, current) =>
                    prev.snackBarMessage != current.snackBarMessage &&
                    current.snackBarMessage != null,
            listener: (context, state) {
              _showFloatingSnackBar(
                context,
                content: Text(state.snackBarMessage!),
                duration:
                    state.snackBarMessage!.contains('magic tap')
                        ? const Duration(seconds: 3)
                        : const Duration(milliseconds: 800),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.read<HomeScreenCubit>().clearSnackBarMessage();
                }
              });
            },
          ),
        ],
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FilterSection(),
                  // Call _buildEntriesList helper method
                  _buildEntriesList(context),
                ],
              ),
              InputArea(
                // Pass context to handlers
                onSendPressed: (text) => _handleInput(context, text),
                showSnackBar: ({
                  required context,
                  required content,
                  Duration? duration,
                  action,
                  backgroundColor,
                }) {
                  _showFloatingSnackBar(
                    context,
                    content: content,
                    duration: duration ?? const Duration(seconds: 4),
                    action: action,
                    backgroundColor: backgroundColor,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep _buildEntriesList as a helper method within StatelessWidget
  Widget _buildEntriesList(BuildContext context) {
    // Need context passed in now
    return EntriesList(
      formatDateHeader: _formatDateHeader,
      getCategoryColor: _getCategoryColor,
      timeFormatter: _timeFormatter,
      onChangeCategoryPressed:
          (entry) => _showChangeCategoryDialog(context, entry),
      onEditPressed: (entry) => _showEditEntryDialog(context, entry),
      // Pass context to delete handler
      onDeletePressed: (entry) => _handleDeleteEntry(context, entry),
    );
  }
}
