import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/entry_cubit.dart';
import '../entry.dart';
import '../utils/category_colors.dart';
import '../widgets/voice_input_section.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final FocusNode _inputFocusNode = FocusNode();
  bool _isInputFocused = false;
  // Add this GlobalKey
  final GlobalKey _inputAreaKey = GlobalKey();

  // --- Easter Egg State ---
  int _titleTapCount = 0;
  final int _targetTapCount = 7;
  // --- End Easter Egg State ---

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
    if (mounted) {
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
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

    // Calculate bottom margin based on input area height
    double bottomMargin = 8.0; // Default gap if key fails
    final RenderBox? inputAreaRenderBox =
        _inputAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputAreaRenderBox != null) {
      final inputAreaHeight = inputAreaRenderBox.size.height;
      // Add a small gap (e.g., 8.0) above the input area
      bottomMargin = inputAreaHeight + 8.0;
    }

    messenger.showSnackBar(
      SnackBar(
        content: content,
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        // Use the dynamically calculated bottom margin
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16.0, right: 16.0),
      ),
    );
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      context.read<EntryCubit>().addEntry(currentInput);
      _textController.clear();
      FocusScope.of(context).unfocus(); // Hide keyboard
      _showFloatingSnackBar(
        context, // Use the main screen context
        content: const Text('Processing entry...'),
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
    showDialog(
      context: context,
      builder:
          (dialogContext) => BlocProvider.value(
            value: BlocProvider.of<EntryCubit>(context),
            child: AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Add custom categories or delete unused ones (except "Misc").',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Flexible(
                      child: BlocBuilder<EntryCubit, EntryState>(
                        builder: (listBuilderContext, state) {
                          if (state.categories.isEmpty) {
                            return const Center(
                              child: Text('No categories found.'),
                            );
                          }
                          final sortedCategories = List<String>.from(
                            state.categories,
                          )..sort();

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
                                        : IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent[100],
                                          ),
                                          tooltip: 'Delete Category',
                                          onPressed: () async {
                                            final entryCubit =
                                                listBuilderContext
                                                    .read<EntryCubit>();
                                            final navigator = Navigator.of(
                                              dialogContext,
                                            );

                                            bool confirmed =
                                                await _showDeleteCategoryConfirmationDialog(
                                                  listBuilderContext,
                                                  category,
                                                );
                                            if (confirmed) {
                                              entryCubit.deleteCategory(
                                                category,
                                              );
                                              navigator.pop();
                                              if (mounted) {
                                                _showFloatingSnackBar(
                                                  context,
                                                  content: Text(
                                                    'Category "$category" deleted',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextField(
                        controller: categoryInputController,
                        decoration: const InputDecoration(
                          labelText: 'New Category Name',
                          hintText: 'Enter category to add...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            BlocProvider.of<EntryCubit>(
                              dialogContext,
                            ).addCustomCategory(value.trim());
                            categoryInputController.clear();
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('Add Category'),
                  onPressed: () {
                    final newCategory = categoryInputController.text.trim();
                    if (newCategory.isNotEmpty) {
                      BlocProvider.of<EntryCubit>(
                        dialogContext,
                      ).addCustomCategory(newCategory);
                      categoryInputController.clear();
                      if (mounted) {
                        _showFloatingSnackBar(
                          context,
                          content: Text('Category "$newCategory" added'),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
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
              title: const Text('Edit Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Entry Text'),
                    maxLines: null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
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
                TextButton(
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
                        dialogContext,
                        content: const Text('Entry text cannot be empty.'),
                        backgroundColor: Colors.red,
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
              child: Text(
                state.filterCategory != null
                    ? 'No entries found for category: "${state.filterCategory}"'
                    : 'No entries yet. Type or use the mic!',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 130.0),
            itemCount: listItems.length,
            itemBuilder: (context, index) {
              final item = listItems[index];

              if (item is DateTime) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    _formatDateHeader(item),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (item is Entry) {
                final entry = item;
                bool isProcessing = entry.category == 'Processing...';
                bool isNew = entry.isNew;
                Color categoryColor = _getCategoryColor(entry.category);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 0,
                  ),
                  color:
                      isNew
                          ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.2)
                          : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(entry.text)),
                            if (isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${_timeFormatter.format(entry.timestamp)} - ${entry.category}',
                          style: TextStyle(
                            color:
                                isProcessing ? Colors.orange : Colors.grey[700],
                          ),
                        ),
                        trailing: _buildEntryActions(entry, isProcessing),
                        dense: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: categoryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            entry.category,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: CategoryColors.getTextColorForCategory(
                                entry.category,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Entries:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              BlocBuilder<EntryCubit, EntryState>(
                buildWhen:
                    (prev, current) =>
                        prev.categories != current.categories ||
                        prev.filterCategory != current.filterCategory,
                builder: (context, state) {
                  // Create sorted list for dropdown, add "All" option
                  final dropdownCategories = ['All Categories']..addAll(
                    List<String>.from(state.categories)..sort(), // Keep sorting
                  );

                  // Determine the value for the dropdown
                  String? dropdownValue = state.filterCategory;
                  if (dropdownValue == null) {
                    dropdownValue = 'All Categories';
                  } else if (!dropdownCategories.contains(dropdownValue)) {
                    dropdownValue = 'All Categories';
                  }

                  return DropdownButton<String>(
                    value: dropdownValue,
                    hint: const Text('Filter by Category'),
                    underline: Container(),
                    items:
                        dropdownCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight:
                                    category == 'All Categories'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue == 'All Categories') {
                        context.read<EntryCubit>().setFilter(null);
                      } else {
                        context.read<EntryCubit>().setFilter(newValue);
                      }
                    },
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Entries grouped by date. Auto-categorized, or assign manually via edit.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        key: _inputAreaKey, // Assign the key here
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              focusNode: _inputFocusNode,
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => _handleInput(),
              minLines: 1,
              maxLines: _isInputFocused ? 5 : 1,
              onTapOutside: (_) {
                if (_inputFocusNode.hasFocus) {
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextFieldTapRegion(
                  child: VoiceInputSection(
                    textController: _textController,
                    inputFocusNode: _inputFocusNode,
                    isInputFocused: _isInputFocused,
                    showSnackBar: _showFloatingSnackBar,
                  ),
                ),
                IconButton(
                  onPressed: _handleInput,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryActions(Entry entry, bool isProcessing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: 'Edit Entry',
          visualDensity: VisualDensity.compact,
          onPressed:
              isProcessing ? null : () => _showEditEntryDialog(context, entry),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.redAccent,
            size: 20,
          ),
          tooltip: 'Delete Entry',
          visualDensity: VisualDensity.compact,
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: GestureDetector(
          onTap: () {
            setState(() {
              _titleTapCount++;
              if (_titleTapCount == _targetTapCount) {
                _showFloatingSnackBar(
                  context,
                  content: const Text('✨ You found the magic tap! ✨'),
                  duration: const Duration(seconds: 3),
                );
                _titleTapCount = 0;
              } else if (_titleTapCount > _targetTapCount) {
                _titleTapCount = 0;
              }
            });
          },
          child: Text(widget.title),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add/Manage Categories',
            onPressed: _showManageCategoriesDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[_buildFilterSection(), _buildEntriesList()],
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
}
