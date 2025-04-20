import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Import async for Timer

import '../cubit/entry_cubit.dart';
import '../cubit/home_screen_cubit.dart';
import '../cubit/home_screen_state.dart';
import '../entry.dart';
import '../utils/category_colors.dart';
import '../widgets/voice_input_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

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

  void _handleInput({String? textToSubmit}) {
    final String currentInput = textToSubmit ?? _textController.text;
    if (currentInput.isNotEmpty) {
      context.read<EntryCubit>().addEntry(currentInput);
      _textController.clear();
      // Only unfocus if not triggered by auto-submit
      if (textToSubmit == null) {
        FocusScope.of(context).unfocus();
      }
      _showFloatingSnackBar(
        context,
        content: const Row(
          children: [
            Icon(
              Icons.pending_actions_outlined,
              size: 18,
              color: Colors.white70,
            ),
            SizedBox(width: 8),
            Text('Processing entry...'),
          ],
        ),
        duration: const Duration(milliseconds: 800),
      );
    }
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
              Text('About Log Everything'),
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

  Widget _buildEntriesList() {
    return Expanded(
      child: BlocBuilder<EntryCubit, EntryState>(
        builder: (context, state) {
          final List<dynamic> listItems = state.displayListItems;

          if (state.isLoading && listItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (listItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  state.filterCategory != null
                      ? 'No entries found for category: "${state.filterCategory}"'
                      : 'No entries yet.\nType or use the mic below!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(
              bottom: 150.0,
              left: 16.0,
              right: 16.0,
            ),
            itemCount: listItems.length,
            separatorBuilder: (context, index) {
              final currentItem = listItems[index];
              final nextItem =
                  (index + 1 < listItems.length) ? listItems[index + 1] : null;
              if (currentItem is Entry && nextItem is Entry) {
                return const SizedBox(height: 8.0);
              }
              return const SizedBox.shrink();
            },
            itemBuilder: (context, index) {
              final item = listItems[index];

              if (item is DateTime) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  child: Text(
                    _formatDateHeader(item),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              } else if (item is Entry) {
                final entry = item;
                bool isProcessing = entry.category == 'Processing...';
                bool isNew = entry.isNew;
                Color categoryColor = _getCategoryColor(entry.category);

                return Card(
                  elevation: isNew ? 4.0 : 1.0,
                  margin: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side:
                        isNew
                            ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            )
                            : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: ListTile(
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(entry.text),
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _timeFormatter.format(entry.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          // Use ActionChip for tappable behavior
                          ActionChip(
                            label: Text(
                              entry.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color:
                                    isProcessing
                                        ? Colors.orange[900]
                                        : CategoryColors.getTextColorForCategory(
                                          entry.category,
                                        ),
                              ),
                            ),
                            backgroundColor:
                                isProcessing
                                    ? Colors.orange.shade100.withOpacity(0.8)
                                    : categoryColor.withOpacity(0.2),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            // Use onPressed for ActionChip
                            onPressed:
                                isProcessing
                                    ? null
                                    : () => _showChangeCategoryDialog(
                                      context,
                                      entry,
                                    ),
                            tooltip: isProcessing ? null : 'Change Category',
                          ),
                        ],
                      ),
                      trailing: _buildEntryActions(entry, isProcessing),
                      dense: true,
                    ),
                  ),
                );
              }
              return Container();
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 4.0,
        bottom: 4.0,
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlocBuilder<EntryCubit, EntryState>(
            buildWhen: (prev, current) {
              bool shouldBuild =
                  prev.categories != current.categories ||
                  prev.filterCategory != current.filterCategory;
              return shouldBuild;
            },
            builder: (context, state) {
              final dropdownCategories = [
                'All Categories',
                ...List<String>.from(state.categories)..sort(),
              ];

              String currentDisplayValue =
                  state.filterCategory ?? 'All Categories';
              if (!dropdownCategories.contains(currentDisplayValue)) {
                currentDisplayValue = 'All Categories';
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentDisplayValue,
                    icon: const Icon(Icons.filter_list_alt, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items:
                        dropdownCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight:
                                    category == currentDisplayValue
                                        ? FontWeight
                                            .bold // Make selected bold
                                        : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      // Add the onChanged callback
                      if (newValue == null) {
                        return;
                      }

                      final cubit = context.read<EntryCubit>();
                      final currentFilter = state.filterCategory;

                      if (newValue == 'All Categories') {
                        if (currentFilter != null) {
                          cubit.setFilter(null);
                        }
                      } else {
                        if (currentFilter != newValue) {
                          cubit.setFilter(newValue);
                        }
                      }
                    },
                    isDense: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
                          onTranscriptionComplete: (transcribedText) {
                            _handleInput(textToSubmit: transcribedText);
                          },
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
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            context.read<HomeScreenCubit>().incrementTitleTap();
          },
          child: Text(widget.title),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).appBarTheme.foregroundColor?.withOpacity(0.7),
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
      body: BlocListener<HomeScreenCubit, HomeScreenState>(
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
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[_buildFilterSection(), _buildEntriesList()],
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }
}
