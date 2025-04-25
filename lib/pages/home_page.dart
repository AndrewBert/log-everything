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
import '../widgets/voice_input_section.dart';
import '../widgets/whats_new_dialog.dart'; // Import the new dialog
import '../widgets/entries_list.dart'; // Import the new EntriesList widget
import '../widgets/filter_section.dart'; // Import the new FilterSection widget

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// Add TickerProviderStateMixin for AnimationController
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChange);
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.removeListener(_onInputFocusChange);
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onInputFocusChange() {
    if (mounted && context.mounted) {
      context.read<HomeScreenCubit>().setInputFocus(_inputFocusNode.hasFocus);
    }
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

    EdgeInsetsGeometry? margin = EdgeInsets.only(
      bottom: 8.0, // Default bottom margin if input area not found
      left: 16.0,
      right: 16.0,
    );

    final RenderBox? inputAreaRenderBox =
        _inputAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputAreaRenderBox != null) {
      final inputAreaHeight = inputAreaRenderBox.size.height;
      margin = EdgeInsets.only(
        bottom: inputAreaHeight + 8.0,
        left: 16.0,
        right: 16.0,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        content: content,
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: margin, // Use calculated or default margin
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

  void _handleInput() {
    final voiceCubit = context.read<VoiceInputCubit>();
    final entryCubit = context.read<EntryCubit>();
    final currentText = _textController.text.trim();

    // Handle manual send during recording
    if (voiceCubit.state.isRecording) {
      AppLogger.info(
        'Send tapped during recording. Stopping and combining text with transcription.',
      );
      HapticFeedback.mediumImpact(); // Add haptic feedback
      // Pass current text to the cubit for background processing
      voiceCubit.stopRecordingAndCombine(currentText);

      _textController.clear();
      FocusScope.of(context).unfocus();
      _showProcessingSnackbar(
        'Processing voice entry...',
      ); // Show generic processing
      return; // Stop further processing here; cubit handles adding entry
    }

    // Handle manual send when NOT recording
    if (currentText.isNotEmpty) {
      entryCubit.addEntry(currentText);
      _showProcessingSnackbar('Processing text entry...');
      _textController.clear();
      FocusScope.of(context).unfocus();
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
    HapticFeedback.lightImpact(); // Add haptic feedback
    final categoryInputController = TextEditingController();
    String feedbackMessage = '';
    Timer? feedbackTimer;
    // Animation controller for feedback text
    late AnimationController feedbackAnimationController;
    late Animation<double> feedbackScaleAnimation;

    feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this, // Use the TickerProviderStateMixin
    );
    feedbackScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: feedbackAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (stfContext, stfSetState) {
              void showFeedback(String message) {
                feedbackTimer?.cancel();
                stfSetState(() {
                  feedbackMessage = message;
                });
                // Trigger animation
                feedbackAnimationController.forward(from: 0.0);
                feedbackTimer = Timer(
                  const Duration(seconds: 2, milliseconds: 500),
                  () {
                    if (mounted) {
                      stfSetState(() {
                        feedbackMessage = '';
                      });
                    }
                  },
                );
              }

              return BlocProvider.value(
                value: BlocProvider.of<EntryCubit>(context),
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Manage Categories'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Add custom categories or delete unused ones.',
                            style: Theme.of(stfContext).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Flexible(
                          child: BlocBuilder<EntryCubit, EntryState>(
                            builder: (listBuilderContext, state) {
                              if (state.categories.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    child: Text('No categories found.'),
                                  ),
                                );
                              }
                              // Sort categories: Most recent first, Misc last
                              final List<String> displayCategories =
                                  List<String>.from(state.categories);
                              displayCategories.remove(
                                'Misc',
                              ); // Remove Misc temporarily
                              final sortedCategories =
                                  displayCategories.reversed
                                      .toList(); // Reverse for most recent first
                              sortedCategories.add(
                                'Misc',
                              ); // Add Misc back at the end

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: sortedCategories.length,
                                itemBuilder: (context, index) {
                                  final category = sortedCategories[index];
                                  final bool isMisc = category == 'Misc';
                                  return ListTile(
                                    title: Text(
                                      category,
                                      style: TextStyle(
                                        color: isMisc ? Colors.grey : null,
                                      ),
                                    ),
                                    dense: true,
                                    trailing:
                                        isMisc
                                            ? null
                                            : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 20,
                                                  ),
                                                  tooltip: 'Rename Category',
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 20,
                                                  onPressed: () async {
                                                    final String? newName =
                                                        await _showEditCategoryDialog(
                                                          stfContext,
                                                          category,
                                                        );
                                                    if (newName != null &&
                                                        newName.isNotEmpty &&
                                                        newName != category) {
                                                      HapticFeedback.mediumImpact(); // Add haptic feedback
                                                      showFeedback(
                                                        'Category renamed to "$newName"',
                                                      );
                                                    }
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.delete_outline,
                                                    color:
                                                        Colors.redAccent[100],
                                                    size: 20,
                                                  ),
                                                  tooltip: 'Delete Category',
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 20,
                                                  onPressed: () async {
                                                    final entryCubit =
                                                        listBuilderContext
                                                            .read<EntryCubit>();

                                                    bool confirmed =
                                                        await _showDeleteCategoryConfirmationDialog(
                                                          listBuilderContext,
                                                          category,
                                                        );
                                                    if (confirmed) {
                                                      HapticFeedback.mediumImpact(); // Add haptic feedback
                                                      entryCubit.deleteCategory(
                                                        category,
                                                      );
                                                      showFeedback(
                                                        'Category "$category" deleted',
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 24),
                        if (feedbackMessage.isNotEmpty)
                          ScaleTransition(
                            scale: feedbackScaleAnimation,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 10.0,
                                top: 4.0,
                              ),
                              child: Text(
                                feedbackMessage,
                                style: TextStyle(
                                  color:
                                      Theme.of(stfContext).colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextField(
                            controller: categoryInputController,
                            decoration: InputDecoration(
                              labelText: 'New Category Name',
                              hintText: 'Enter category to add...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                final newCategory = value.trim();
                                HapticFeedback.mediumImpact(); // Add haptic feedback
                                BlocProvider.of<EntryCubit>(
                                  dialogContext,
                                ).addCustomCategory(newCategory);
                                categoryInputController.clear();
                                showFeedback('Category "$newCategory" added');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Done'),
                      onPressed: () {
                        feedbackTimer?.cancel();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    FilledButton(
                      child: const Text('Add Category'),
                      onPressed: () {
                        final newCategory = categoryInputController.text.trim();
                        if (newCategory.isNotEmpty) {
                          HapticFeedback.mediumImpact(); // Add haptic feedback
                          BlocProvider.of<EntryCubit>(
                            dialogContext,
                          ).addCustomCategory(newCategory);
                          categoryInputController.clear();
                          showFeedback('Category "$newCategory" added');
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
    ).whenComplete(() {
      feedbackTimer?.cancel();
      feedbackAnimationController.dispose(); // Dispose controller on dismiss
    });
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

  void _showEditEntryDialog(BuildContext context, Entry originalEntry) {
    final editController = TextEditingController(text: originalEntry.text);
    String selectedCategory = originalEntry.category;

    final currentState = context.read<EntryCubit>().state;
    final availableCategories = List<String>.from(currentState.categories)
      ..sort();

    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Entry Text',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items:
                        availableCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        stfSetState(() {
                          selectedCategory = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                FilledButton(
                  child: const Text('Update'),
                  onPressed: () {
                    final updatedText = editController.text.trim();
                    if (updatedText.isNotEmpty) {
                      final updatedEntry = Entry(
                        text: updatedText,
                        category: selectedCategory,
                        timestamp: originalEntry.timestamp,
                      );
                      context.read<EntryCubit>().updateEntry(
                        originalEntry,
                        updatedEntry,
                      );
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        _showFloatingSnackBar(
                          context,
                          content: const Text('Entry updated'),
                          duration: const Duration(seconds: 1),
                        );
                      }
                    } else {
                      _showFloatingSnackBar(
                        stfContext,
                        content: const Text('Entry text cannot be empty.'),
                        backgroundColor: Colors.redAccent,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

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

    final String? newCategory = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Change Category'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children:
              availableCategories.map((category) {
                return SimpleDialogOption(
                  onPressed: () {
                    HapticFeedback.selectionClick(); // Add haptic feedback
                    Navigator.pop(dialogContext, category);
                  },
                  child: Text(
                    category,
                    style: TextStyle(
                      fontWeight:
                          category == selectedCategory
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color:
                          category == selectedCategory
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );

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

  void _showHelpDialog() {
    HapticFeedback.lightImpact(); // Add haptic feedback
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text('About Log Splitter'), // Updated title
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivation:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'This app helps you quickly capture thoughts, tasks, or events using voice or text, automatically categorizing them for easy review later.',
                ),
                SizedBox(height: 12),
                Text(
                  'Purpose & Key Features:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '- Log entries via text input or voice dictation.\n'
                  '- Automatic categorization using AI (powered by OpenAI).\n'
                  '- View entries grouped by date.\n'
                  '- Filter entries by category.\n'
                  '- Manage custom categories.\n'
                  '- Edit or delete existing entries.',
                ),
                SizedBox(height: 12),
                Text(
                  'Feedback:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Your feedback is valuable! Please report any bugs, suggest improvements, or share your experience, especially regarding:\n'
                  '- Accuracy of voice transcription.\n'
                  '- Relevance of AI categorization.\n'
                  '- Overall usability and workflow.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Add button to show What's New
            TextButton(
              child: const Text("What's New"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close help dialog first
                _showWhatsNewDialog(); // Show the What's New dialog
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
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

  Widget _buildInputArea() {
    return BlocBuilder<HomeScreenCubit, HomeScreenState>(
      buildWhen:
          (prev, current) => prev.isInputFocused != current.isInputFocused,
      builder: (context, state) {
        final isInputFocused = state.isInputFocused;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 8.0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Container(
              key: _inputAreaKey,
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: TextField(
                focusNode: _inputFocusNode,
                controller: _textController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.6),
                  labelText: isInputFocused ? 'Enter log entry' : null,
                  hintText: 'What happened?...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        VoiceInputSection(
                          textController: _textController,
                          inputFocusNode: _inputFocusNode,
                          isInputFocused: isInputFocused,
                          showSnackBar: _showFloatingSnackBar,
                        ),
                        IconButton(
                          onPressed:
                              () =>
                                  _handleInput(), // Call without args for manual send
                          icon: const Icon(Icons.send_rounded),
                          color: Theme.of(context).colorScheme.primary,
                          iconSize: 28,
                          tooltip: 'Add Entry',
                        ),
                      ],
                    ),
                  ),
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _handleInput(),
                minLines: 1,
                maxLines: 5,
                onTapOutside: (_) {
                  if (_inputFocusNode.hasFocus) {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryActions(Entry entry, bool isProcessing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(right: 4.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit Entry',
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          onPressed:
              isProcessing ? null : () => _showEditEntryDialog(context, entry),
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.redAccent.shade100,
            size: 18,
          ),
          tooltip: 'Delete Entry',
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          onPressed:
              isProcessing
                  ? null
                  : () {
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
                            context.read<EntryCubit>().addEntryObject(
                              entryToDelete,
                            );
                          },
                        ),
                      );
                    }
                  },
        ),
      ],
    );
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
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
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
                  const FilterSection(), // <-- Use the new widget
                  _buildEntriesList(),
                ],
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntriesList() {
    // This method is now replaced by the EntriesList widget.
    return EntriesList(
      formatDateHeader: _formatDateHeader,
      getCategoryColor: _getCategoryColor,
      buildEntryActions: _buildEntryActions,
      timeFormatter: _timeFormatter,
      onChangeCategoryPressed:
          (entry) => _showChangeCategoryDialog(
            context,
            entry,
          ), // <-- Pass the dialog function
    );
  }
}
