import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/cubit/voice_input_cubit.dart'; // <-- Re-add VoiceInputCubit import
import 'package:myapp/utils/logger.dart';
import 'dart:async'; // Import async for Timer
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus

import '../cubit/entry_cubit.dart';
import '../cubit/home_screen_cubit.dart';
import '../cubit/home_screen_state.dart';
import '../entry.dart';
import '../utils/category_colors.dart';
import '../widgets/whats_new_dialog.dart'; // Import the new dialog
import '../widgets/entries_list.dart'; // Import the new EntriesList widget
import '../widgets/filter_section.dart'; // Import the new FilterSection widget
import '../widgets/input_area.dart';
import '../dialogs/edit_entry_dialog.dart';
import '../dialogs/manage_categories_dialog.dart';
import '../dialogs/change_category_dialog.dart';
import '../dialogs/help_dialog.dart'; // <-- Import the new dialog

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DateFormat _timeFormatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showFloatingSnackBar(
    BuildContext targetContext, {
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.hideCurrentSnackBar();

    // Calculate margin based on keyboard visibility or a fixed offset
    // This is a simplification; a more robust solution might involve
    // listening to keyboard changes or using MediaQuery.viewInsets
    final keyboardVisible = MediaQuery.of(targetContext).viewInsets.bottom > 0;
    final bottomPadding = MediaQuery.of(targetContext).padding.bottom;
    final double bottomMargin =
        keyboardVisible
            ? MediaQuery.of(targetContext).viewInsets.bottom + 8.0
            : bottomPadding + 80.0; // Estimate input area height + padding

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

  Future<void> _showWhatsNewDialog([String? version]) async {
    if (!mounted) return;

    String currentVersion = version ?? '';
    // Fetch version only if not provided (e.g., manual trigger)
    if (currentVersion.isEmpty) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        // Use the format from the cubit (includes build number)
        currentVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      } catch (e, stackTrace) {
        AppLogger.error(
          'Error getting package info for What\'s New dialog: $e',
          stackTrace: stackTrace,
        );
        if (mounted) {
          _showFloatingSnackBar(
            context,
            content: const Text('Could not load version info.'),
            backgroundColor: Colors.redAccent,
          );
        }
        return; // Don't show dialog if version fetch fails
      }
    }

    // Extract only the version number (e.g., "1.2.0") for display in the dialog title
    String displayVersion = currentVersion;
    final versionMatch = RegExp(
      r'v([0-9]+\.[0-9]+\.[0-9]+)',
    ).firstMatch(currentVersion);
    if (versionMatch != null) {
      displayVersion = versionMatch.group(1) ?? currentVersion;
    }

    // Check mounted again before showing dialog
    if (!mounted) return;
    // Use rootNavigator: true if showing from within another dialog like Help
    await showDialog(
      context: context,
      builder:
          (dialogContext) => WhatsNewDialog(
            currentVersion: displayVersion, // Pass only the version number part
          ),
    );
  }

  void _handleInput(String currentText) {
    final voiceCubit = context.read<VoiceInputCubit>();
    final entryCubit = context.read<EntryCubit>();

    // Handle manual send during recording
    if (voiceCubit.state.isRecording) {
      AppLogger.info(
        'Send tapped during recording. Stopping and combining text with transcription.',
      );
      HapticFeedback.mediumImpact(); // Add haptic feedback
      // Pass current text to the cubit for background processing
      voiceCubit.stopRecordingAndCombine(currentText);

      _showProcessingSnackbar(
        'Processing voice entry...',
      ); // Show generic processing
      return; // Stop further processing here; cubit handles adding entry
    }

    // Handle manual send when NOT recording
    if (currentText.isNotEmpty) {
      entryCubit.addEntry(currentText);
      _showProcessingSnackbar('Processing text entry...');
    }
  }

  // Helper to show consistent processing snackbar
  void _showProcessingSnackbar(String message) {
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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Confirm Delete Category'),
              content: Text(
                '''Are you sure you want to delete the category "$category"?
Entries using this category will be moved to "Misc".''',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showManageCategoriesDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Provide the necessary cubit to the dialog subtree
        // (Assuming EntryCubit is already provided above HomePage)
        return ManageCategoriesDialog(
          // Pass the existing dialog functions as callbacks
          onShowEditCategoryDialog: _showEditCategoryDialog,
          onShowDeleteCategoryConfirmationDialog:
              _showDeleteCategoryConfirmationDialog,
        );
      },
    );
  }

  Future<String?> _showEditCategoryDialog(
    BuildContext context, // Use the context passed from the manage dialog
    String oldCategoryName,
  ) async {
    final editCategoryController = TextEditingController(text: oldCategoryName);
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Rename Category'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: editCategoryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Category Name',
                hintText: 'Enter new name...',
              ),
              validator: (value) {
                final newName = value?.trim() ?? '';
                if (newName.isEmpty) {
                  return 'Category name cannot be empty.';
                }
                if (newName == oldCategoryName) {
                  return 'Please enter a different name.';
                }
                // Check if the name already exists (case-insensitive)
                final existingCategories =
                    context.read<EntryCubit>().state.categories;
                if (existingCategories.any(
                  (cat) => cat.toLowerCase() == newName.toLowerCase(),
                )) {
                  return 'Category "$newName" already exists.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(), // Return null
            ),
            FilledButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newName = editCategoryController.text.trim();
                  // Call the cubit method (to be implemented)
                  context.read<EntryCubit>().renameCategory(
                    oldCategoryName,
                    newName,
                  );
                  Navigator.of(
                    dialogContext,
                  ).pop(newName); // Return the new name
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditEntryDialog(
    BuildContext context,
    Entry originalEntry,
  ) async {
    // Show the new dialog and wait for the result (updated entry or null)
    final Entry? updatedEntry = await showDialog<Entry?>(
      context: context,
      builder: (dialogContext) {
        // Provide the necessary cubit to the dialog subtree
        return BlocProvider.value(
          value: BlocProvider.of<EntryCubit>(context),
          child: EditEntryDialog(originalEntry: originalEntry),
        );
      },
    );

    // If an entry was returned (meaning update was successful)
    if (updatedEntry != null && mounted) {
      _showFloatingSnackBar(
        context,
        content: const Text('Entry updated'),
        duration: const Duration(seconds: 1),
      );
    }
  }

  // Update _showChangeCategoryDialog to use the new widget
  Future<void> _showChangeCategoryDialog(
    BuildContext context,
    Entry entry,
  ) async {
    final entryCubit = context.read<EntryCubit>();
    final availableCategories = List<String>.from(entryCubit.state.categories)
      ..sort();
    String? selectedCategory = entry.category;

    // Ensure the current category is valid, default to Misc if not
    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    // Use the new ChangeCategoryDialog widget
    final String? newCategory = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return ChangeCategoryDialog(
          currentCategory: selectedCategory,
          availableCategories: availableCategories,
        );
      },
    );

    // Keep the logic to handle the result
    if (newCategory != null && newCategory != entry.category) {
      final updatedEntry = entry.copyWith(category: newCategory);
      entryCubit.updateEntry(entry, updatedEntry);
      if (mounted) {
        _showFloatingSnackBar(
          context,
          content: Text('Category changed to "$newCategory"'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  // Update _showHelpDialog to use the new widget
  void _showHelpDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return HelpDialog(
          // Pass the existing method as a callback
          onShowWhatsNewPressed: () => _showWhatsNewDialog(),
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

  // Create a helper method for delete logic
  void _handleDeleteEntry(Entry entry) {
    final entryToDelete = entry;
    context.read<EntryCubit>().deleteEntry(entryToDelete);
    if (mounted) {
      _showFloatingSnackBar(
        context,
        content: const Text('Entry deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            context.read<EntryCubit>().addEntryObject(entryToDelete);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color? defaultTitleColor =
        Theme.of(context).appBarTheme.titleTextStyle?.color;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            context.read<HomeScreenCubit>().incrementTitleTap();
          },
          // Replace Text with RichText for multi-colored title
          child: RichText(
            text: TextSpan(
              // Default style for the title (taken from AppBar theme or default)
              style:
                  Theme.of(context).appBarTheme.titleTextStyle ??
                  Theme.of(context).textTheme.titleLarge,
              children: <TextSpan>[
                TextSpan(
                  text: 'Log',
                  style: TextStyle(
                    color: primaryColor, // Color for "Log"
                    fontWeight: FontWeight.bold, // Optional: make it bold
                  ),
                ),
                TextSpan(
                  text: ' Splitter', // Note the leading space
                  style: TextStyle(
                    color: defaultTitleColor, // Color for "Splitter" (default)
                  ),
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
                    // Add Text widget to display the version
                    child: Text(
                      state.appVersion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87, // Changed to a dark color
                      ),
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
            // This now calls the updated method which shows the new dialog
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            // This now calls the updated method which shows the new dialog
            onPressed: _showManageCategoriesDialog,
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
              await _showWhatsNewDialog(state.appVersion);
              if (mounted) {
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
                  _buildEntriesList(), // This method now returns the updated EntriesList
                ],
              ),
              InputArea(
                onSendPressed: _handleInput,
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

  // Update the _buildEntriesList method to pass the new callbacks
  Widget _buildEntriesList() {
    return EntriesList(
      formatDateHeader: _formatDateHeader,
      getCategoryColor: _getCategoryColor,
      timeFormatter: _timeFormatter,
      onChangeCategoryPressed:
          (entry) => _showChangeCategoryDialog(context, entry),
      onEditPressed:
          (entry) =>
              _showEditEntryDialog(context, entry), // <-- Pass edit dialog
      onDeletePressed: _handleDeleteEntry, // <-- Pass delete handler
    );
  }
}
