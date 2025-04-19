import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cubit/entry_cubit.dart';
import '../cubit/voice_input_cubit.dart';
import '../cubit/voice_input_state.dart';
import '../entry.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  String? _selectedCategoryFilter;
  // --- Add FocusNode and state variable ---
  final FocusNode _inputFocusNode = FocusNode();
  bool _isInputFocused = false;
  // --- End FocusNode ---

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

  // --- Add focus change handler ---
  void _onInputFocusChange() {
    if (mounted) {
      // Check if widget is still mounted
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
    }
  }
  // --- End focus change handler ---

  // --- Helper to show consistent floating SnackBars ---
  void _showFloatingSnackBar(
    BuildContext targetContext, {
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: content,
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 150.0, left: 16.0, right: 16.0),
      ),
    );
  }
  // --- End Helper ---

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

  // --- Category Management Dialog ---
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
                    // --- Add helper text for the dialog ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Add custom categories or delete unused ones (except "Misc").',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // --- End helper text ---
                    Flexible(
                      child: BlocBuilder<EntryCubit, EntryState>(
                        // --- Use the BlocBuilder's context for Cubit/Navigator/Dialogs inside the list ---
                        builder: (listBuilderContext, state) {
                          if (state.categories.isEmpty) {
                            return const Text('No categories found.');
                          }
                          // Create a mutable copy and sort it
                          final sortedCategories = List<String>.from(
                            state.categories,
                          )..sort();

                          return ListView.builder(
                            shrinkWrap: true, // Important in Flexible
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
                                            final scaffoldMessenger =
                                                ScaffoldMessenger.of(
                                                  dialogContext,
                                                );

                                            bool confirmed =
                                                await _showDeleteCategoryConfirmationDialog(
                                                  listBuilderContext,
                                                  category,
                                                );
                                            if (confirmed && mounted) {
                                              entryCubit.deleteCategory(
                                                category,
                                              );

                                              navigator.pop();
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
                                          },
                                        ),
                              );
                            },
                          );
                        },
                        // --- End BlocBuilder context usage ---
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
                            context.read<EntryCubit>().addCustomCategory(
                              value.trim(),
                            );
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
                      _showFloatingSnackBar(
                        context,
                        content: Text('Category "$newCategory" added'),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  // --- UI for Entry Editing ---
  void _showEditEntryDialog(BuildContext context, Entry originalEntry) {
    final editController = TextEditingController(text: originalEntry.text);
    String selectedCategory =
        originalEntry.category; // Initialize with current category

    // Access the Cubit state directly here, as we need the categories for the dropdown
    // No need for BlocProvider.value here since we get it from the main context
    final currentState = context.read<EntryCubit>().state;
    final availableCategories = List<String>.from(currentState.categories)
      ..sort(); // Get sorted list

    // Ensure the original entry's category is valid, default to Misc if not
    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        // This context is specific to the dialog
        // Use a StatefulWidget for the dialog content to manage the dropdown state locally
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
                    maxLines: null, // Allow multiple lines
                  ),
                  const SizedBox(height: 16),
                  // Dropdown to select category
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
                        // Use the StatefulWidget's setState to update the dropdown selection
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
                      // Create the updated entry object, keeping original timestamp
                      final updatedEntry = Entry(
                        text: updatedText,
                        category: selectedCategory,
                        timestamp: originalEntry.timestamp,
                      );
                      // Call cubit method using the main context
                      context.read<EntryCubit>().updateEntry(
                        originalEntry,
                        updatedEntry,
                      );
                      Navigator.of(dialogContext).pop(); // Close dialog
                      if (mounted) {
                        _showFloatingSnackBar(
                          context, // Use the main screen context
                          content: const Text('Entry updated'),
                          duration: const Duration(seconds: 1),
                        );
                      }
                    } else {
                      // Show error SnackBar using the helper
                      _showFloatingSnackBar(
                        dialogContext, // Show within the dialog context here
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

  // --- Helper to Format Date Headers (Remains the same) ---
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

  // --- List Display Area ---
  Widget _buildEntriesList() {
    return Expanded(
      child: BlocBuilder<EntryCubit, EntryState>(
        builder: (context, state) {
          if (state.isLoading && state.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apply filtering
          final List<Entry> filteredEntries =
              _selectedCategoryFilter == null
                  ? state.entries
                  : state.entries
                      .where(
                        (entry) => entry.category == _selectedCategoryFilter,
                      )
                      .toList();

          // Sort entries by timestamp (descending)
          filteredEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (filteredEntries.isEmpty) {
            return Center(
              child: Text(
                _selectedCategoryFilter != null
                    ? 'No entries found for category: "$_selectedCategoryFilter"'
                    : 'No entries yet. Type or use the mic to add your first log!',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          // Group entries by date for section headers
          final List<dynamic> listItems = [];
          final groupedEntries = groupBy<Entry, DateTime>(
            filteredEntries,
            (entry) => DateTime(
              entry.timestamp.year,
              entry.timestamp.month,
              entry.timestamp.day,
            ),
          );

          // Sort dates descending to show newest first
          final sortedDates =
              groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

          for (var date in sortedDates) {
            listItems.add(date); // Add date header
            // Sort entries within the date descending
            final entriesOnDate =
                groupedEntries[date]!
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            listItems.addAll(entriesOnDate); // Add entries for that date
          }

          // Build the list with headers and entry items
          return ListView.builder(
            // Add padding at the bottom to avoid overlap with input area
            padding: const EdgeInsets.only(
              bottom: 130.0,
            ), // Adjust value as needed
            itemCount: listItems.length,
            itemBuilder: (context, index) {
              final item = listItems[index];

              if (item is DateTime) {
                // Date Header
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
                // Entry Item
                final entry = item;
                bool isProcessing = entry.category == 'Processing...';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4.0, // Add some vertical space
                    horizontal: 0,
                  ),
                  child: ListTile(
                    title: Text(entry.text),
                    subtitle: Text(
                      '${_timeFormatter.format(entry.timestamp)} - ${entry.category}',
                      style: TextStyle(
                        color:
                            isProcessing
                                ? Colors
                                    .orange // Indicate processing
                                : Colors.grey[700],
                      ),
                    ),
                    trailing: _buildEntryActions(entry, isProcessing),
                    dense: true,
                  ),
                );
              }
              return Container(); // Should not happen
            },
          );
        },
      ),
    );
  }

  // --- Filter Section ---
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        // Wrap in Column to add text below the Row
        crossAxisAlignment: CrossAxisAlignment.start, // Align text left
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Entries:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              BlocBuilder<EntryCubit, EntryState>(
                builder: (context, state) {
                  if (state.categories.isEmpty && !state.isLoading) {
                    return const SizedBox.shrink(); // Hide if no categories
                  }
                  // Create a mutable, sorted list for the dropdown
                  final sortedCategories = List<String>.from(state.categories)
                    ..sort();

                  List<DropdownMenuItem<String?>> dropdownItems = [
                    const DropdownMenuItem<String?>(
                      value: null, // Represent "All Categories"
                      child: Text("All Categories"),
                    ),
                    ...sortedCategories.map((String category) {
                      // Use spread operator
                      return DropdownMenuItem<String?>(
                        value: category,
                        child: Text(category),
                      );
                    }),
                  ];

                  return Tooltip(
                    // Keep the tooltip for the dropdown
                    message: 'Filter entries by category',
                    child: DropdownButton<String?>(
                      value: _selectedCategoryFilter,
                      hint: const Text("Filter"),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategoryFilter = newValue;
                        });
                      },
                      items: dropdownItems,
                    ),
                  );
                },
              ),
            ],
          ),
          // --- Add explanatory text ---
          Padding(
            padding: const EdgeInsets.only(top: 4.0), // Add some space
            child: Text(
              // Updated text
              'Entries grouped by date. Auto-categorized, or assign manually via edit.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600], // Subtle color
              ),
            ),
          ),
          // --- End explanatory text ---
        ],
      ),
    );
  }

  // --- Input Area ---
  Widget _buildInputArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Use theme card color
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, -2), // Shadow upwards
            ),
          ],
        ),
        // --- Change outer Row to Column ---
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take minimum vertical space
          children: [
            // --- TextField remains largely the same ---
            TextField(
              focusNode: _inputFocusNode, // Assign FocusNode
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
                isDense: true, // Make it more compact
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ), // Adjust padding
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => _handleInput(),
              minLines: 1,
              maxLines: _isInputFocused ? 5 : 1,
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
            // --- Add padding between TextField and buttons ---
            const SizedBox(height: 8),
            // --- Add inner Row for buttons, aligned to end ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Microphone Button - Now using BlocBuilder for state
                BlocBuilder<VoiceInputCubit, VoiceInputState>(
                  builder: (context, state) {
                    // Handle transcribed text when available
                    if (state.transcriptionStatus ==
                            TranscriptionStatus.success &&
                        state.transcribedText != null) {
                      // Set text in controller and clear transcribed text
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _textController.text = state.transcribedText!;
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );
                        context.read<VoiceInputCubit>().clearTranscribedText();
                      });
                    }

                    return IconButton(
                      icon: Icon(
                        state.isRecording
                            ? Icons.stop_circle_outlined
                            : Icons.mic,
                        color:
                            state.isRecording
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                      ),
                      tooltip:
                          state.isRecording
                              ? 'Stop Recording'
                              : 'Start Voice Input',
                      iconSize: 30,
                      onPressed:
                          () =>
                              context.read<VoiceInputCubit>().toggleRecording(),
                    );
                  },
                ),
                // Send Button
                IconButton(
                  onPressed: _handleInput,
                  icon: const Icon(Icons.send),
                  color:
                      Theme.of(context).colorScheme.primary, // Use theme color
                ),
              ],
            ),
          ],
        ),
        // --- End Column ---
      ),
    );
  }

  // --- Entry Item Actions ---
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
        // Edit Button
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: 'Edit Entry',
          visualDensity: VisualDensity.compact,
          onPressed:
              isProcessing
                  ? null // Disable if processing
                  : () => _showEditEntryDialog(context, entry),
        ),
        // Delete Button
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
                  ? null // Disable if processing
                  : () {
                    final entryToDelete = entry;
                    context.read<EntryCubit>().deleteEntry(entryToDelete);
                    if (mounted) {
                      // Remove previous snackbar is handled by the helper now
                      _showFloatingSnackBar(
                        context, // Use the main screen context
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
        title: Text(widget.title),
        actions: [
          IconButton(
            // Change the icon
            icon: const Icon(Icons.playlist_add),
            // Update the tooltip
            tooltip: 'Add/Manage Categories',
            onPressed: _showManageCategoriesDialog,
          ),
        ],
      ),
      // Use SafeArea to avoid OS intrusions (notch, bottom bar)
      body: SafeArea(
        child: Stack(
          children: [
            // Main content column (list, filters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[_buildFilterSection(), _buildEntriesList()],
              ),
            ),

            _buildInputArea(),

            // TODO: Consider refactoring the VoiceInputCubit listener.
            // It's currently placed directly in the main screen build method.
            // Options:
            // 1. Extract the microphone button and this listener into a dedicated
            //    `VoiceInputWidget` to encapsulate voice-related logic and UI.
            // 2. Re-evaluate if a Cubit is necessary or if state management for
            //    voice input can be handled differently (e.g., local StatefulWidget state
            //    if complexity remains low).
            // Add BlocListener to show messages based on VoiceInputState
            BlocListener<VoiceInputCubit, VoiceInputState>(
              listenWhen: (previous, current) {
                // Only trigger for changes in status or new errors
                bool permissionChanged =
                    previous.micPermissionStatus != current.micPermissionStatus;
                bool errorChanged =
                    previous.errorMessage != current.errorMessage &&
                    current.errorMessage != null;
                bool transcriptionStatusChanged =
                    previous.transcriptionStatus != current.transcriptionStatus;

                return permissionChanged ||
                    errorChanged ||
                    transcriptionStatusChanged;
              },
              listener: (context, state) {
                // Permission Denied
                if ((state.micPermissionStatus == PermissionStatus.denied ||
                        state.micPermissionStatus ==
                            PermissionStatus.permanentlyDenied) &&
                    state.isRecording) {
                  _showFloatingSnackBar(
                    context,
                    content: const Text(
                      'Microphone permission is required for voice input.',
                    ),
                  );
                }

                // Handle errors
                if (state.errorMessage != null) {
                  _showFloatingSnackBar(
                    context,
                    content: Text(state.errorMessage!),
                    backgroundColor: Colors.red, // Optional: Indicate error
                  );
                }

                // Handle transcription status
                if (state.transcriptionStatus ==
                    TranscriptionStatus.transcribing) {
                  _showFloatingSnackBar(
                    context,
                    content: const Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(width: 15),
                        Text('Transcribing audio...'),
                      ],
                    ),
                    duration: const Duration(seconds: 10),
                  );
                } else if (state.transcriptionStatus ==
                    TranscriptionStatus.success) {
                  // Hide transcribing snackbar is handled by the helper
                  _showFloatingSnackBar(
                    context,
                    content: const Text('Transcription successful!'),
                    duration: const Duration(seconds: 2),
                  );
                }
              },
              child: const SizedBox.shrink(), // Provide an empty child
            ),
          ],
        ),
      ),
    );
  }
}
