import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus

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
  final GlobalKey _inputAreaKey = GlobalKey();

  // --- Easter Egg State ---
  int _titleTapCount = 0;
  final int _targetTapCount = 7;
  // --- End Easter Egg State ---

  String _appVersion = ''; // State variable for version

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChange);
    _loadVersionInfo(); // Load version on init
  }

  // Function to load version info
  Future<void> _loadVersionInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (${info.buildNumber})';
      });
    }
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

    double bottomMargin = 8.0;
    final RenderBox? inputAreaRenderBox =
        _inputAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputAreaRenderBox != null) {
      final inputAreaHeight = inputAreaRenderBox.size.height;
      bottomMargin = inputAreaHeight + 8.0;
    }

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

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      context.read<EntryCubit>().addEntry(currentInput);
      _textController.clear();
      FocusScope.of(context).unfocus();
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
    showDialog(
      context: context,
      builder:
          (dialogContext) => BlocProvider.value(
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
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Text('No categories found.'),
                              ),
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
                    const Divider(height: 24),
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
                FilledButton(
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
                  // Reduced top padding for the date header
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
                          Chip(
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
        bottom: 4.0, // Added a little bottom padding
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Align content to the right
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlocBuilder<EntryCubit, EntryState>(
            buildWhen: (prev, current) {
              // Check if categories or filter changed
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

              // Calculate the value to display
              String currentDisplayValue =
                  state.filterCategory ?? 'All Categories';
              if (!dropdownCategories.contains(currentDisplayValue)) {
                // Fallback if state is inconsistent
                currentDisplayValue = 'All Categories';
              }

              // Wrap DropdownButton in a styled Container
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 0,
                ), // Adjust padding inside the container
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant
                      .withOpacity(0.4), // Subtle background
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                ),
                child: DropdownButtonHideUnderline(
                  // Hide default underline here
                  child: DropdownButton<String>(
                    value: currentDisplayValue,
                    icon: const Icon(
                      Icons.filter_list_alt,
                      size: 20,
                    ), // Slightly smaller icon
                    style: TextStyle(
                      // Base style for dropdown text
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
                                // Style applied within item
                                fontWeight:
                                    category == currentDisplayValue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
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
            right: 8, // Adjusted padding for integrated icons
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
          // Use only the TextField here, buttons go into decoration
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
              labelText: _isInputFocused ? 'Enter log entry' : null,
              hintText: 'What happened?...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              // Integrate buttons into suffixIcon
              suffixIcon: Padding(
                padding: const EdgeInsets.only(
                  right: 4.0,
                ), // Add padding to align icons
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Prevent row from expanding
                  mainAxisAlignment:
                      MainAxisAlignment.end, // Align icons to the end
                  children: [
                    // Voice Input Button
                    VoiceInputSection(
                      textController: _textController,
                      inputFocusNode: _inputFocusNode,
                      isInputFocused: _isInputFocused,
                      showSnackBar: _showFloatingSnackBar,
                    ),
                    // Send Button
                    IconButton(
                      onPressed: _handleInput,
                      icon: const Icon(Icons.send_rounded),
                      color: Theme.of(context).colorScheme.primary,
                      iconSize: 28,
                      tooltip: 'Add Entry',
                      // Reduce splash radius if needed for tighter space
                      // splashRadius: 24,
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
            setState(() {
              _titleTapCount++;
              if (_titleTapCount == _targetTapCount) {
                _showFloatingSnackBar(
                  context,
                  content: const Text('✨ You found the magic tap! ✨'),
                  duration: const Duration(seconds: 3),
                );
                _titleTapCount = 0;
              } else if (_titleTapCount > _targetTapCount / 2) {
                _showFloatingSnackBar(
                  context,
                  content: Text(
                    '${_targetTapCount - _titleTapCount} taps remaining...',
                  ),
                  duration: const Duration(milliseconds: 500),
                );
              } else if (_titleTapCount > _targetTapCount) {
                _titleTapCount = 0;
              }
            });
          },
          child: Text(widget.title),
        ),
        actions: [
          // Display version number if available
          if (_appVersion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).appBarTheme.foregroundColor?.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: _showManageCategoriesDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
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
    );
  }
}
