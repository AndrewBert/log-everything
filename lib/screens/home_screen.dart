import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart'; // Added
import 'package:path_provider/path_provider.dart'; // Added
import 'package:record/record.dart'; // Added
import 'dart:io'; // Added for Directory
import 'package:collection/collection.dart'; // Import for groupBy

import '../entry.dart';
import '../cubit/entry_cubit.dart';
import '../speech_service.dart'; // Added

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

  // --- Voice Input State ---
  late final AudioRecorder _audioRecorder;
  late final SpeechService _speechService;
  bool _isRecording = false;
  String? _audioPath;
  // --- End Voice Input State ---

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _speechService = SpeechService(); // Initialize SpeechService
    _requestMicPermission(); // Request permission on init
    // --- Add listener to FocusNode ---
    _inputFocusNode.addListener(_onInputFocusChange);
    // --- End listener ---
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose(); // Dispose recorder
    // --- Dispose FocusNode and remove listener ---
    _inputFocusNode.removeListener(_onInputFocusChange);
    _inputFocusNode.dispose();
    // --- End dispose ---
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

  // --- Microphone Permission ---
  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denial (optional: show a message)
      print("Microphone permission denied.");
      if (mounted) {
        // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice input.'),
          ),
        );
      }
    }
  }

  // --- Voice Recording and Transcription Logic ---
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      await _requestMicPermission(); // Request again if needed
      // Check again after requesting
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot record without microphone permission.'),
            ),
          );
        }
        return;
      }
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      _audioPath =
          '${tempDir.path}/temp_audio.m4a'; // Use m4a for wider compatibility

      // Ensure directory exists (mainly for robustness)
      final file = File(_audioPath!);
      if (await file.exists()) {
        await file.delete(); // Delete previous recording if exists
      }

      print("Starting recording to: $_audioPath");

      // Start recording to file
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc), // Using AAC LC encoder
        path: _audioPath!,
      );

      // Short delay to ensure the file is created before checking existence
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if recording actually started
      bool isRecording = await _audioRecorder.isRecording();
      if (isRecording) {
        if (mounted) {
          setState(() {
            _isRecording = true;
          });
        }
        print("Recording started successfully.");
      } else {
        print("Error: Recording failed to start.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start recording.')),
          );
          setState(() {
            _isRecording = false; // Ensure state is consistent
          });
        }
      }
    } catch (e, stacktrace) {
      print('Error starting recording: $e');
      print('Stacktrace: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
        setState(() {
          _isRecording = false; // Reset state on error
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return; // Prevent stopping if not recording

    try {
      final path = await _audioRecorder.stop();
      print("Recording stopped. File path: $path");
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      if (path != null) {
        _audioPath = path; // Use the path returned by stop()
        print("Audio saved to: $_audioPath");
        _transcribeAudio(); // Start transcription
      } else {
        print("Error: Stop recording returned null path.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save recording.')),
          );
        }
      }
    } catch (e, stacktrace) {
      print('Error stopping recording: $e');
      print('Stacktrace: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping recording: $e')));
        setState(() {
          _isRecording = false; // Reset state on error
        });
      }
    }
  }

  Future<void> _transcribeAudio() async {
    if (_audioPath == null || _audioPath!.isEmpty) {
      print("Transcription Error: Audio path is null or empty.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio file found to transcribe.')),
        );
      }
      return;
    }

    // Show visual feedback that transcription is happening
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(width: 15),
              Text('Transcribing audio...'),
            ],
          ),
          duration: Duration(seconds: 10), // Adjust duration as needed
        ),
      );
    }

    try {
      final transcription = await _speechService.transcribeAudio(_audioPath!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide processing indicator
      }

      if (transcription != null && transcription.isNotEmpty) {
        if (mounted) {
          setState(() {
            _textController.text = transcription; // Update text field
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            ); // Move cursor to end
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcription successful!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcription failed or returned empty text.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide processing indicator
        print('Error during transcription: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transcription error: $e')));
      }
    } finally {
      // Optional: Clean up the audio file after transcription attempt
      // final file = File(_audioPath!);
      // if (await file.exists()) {
      //   await file.delete();
      //   print("Deleted temporary audio file: $_audioPath");
      // }
      // _audioPath = null; // Reset path
    }
  }
  // --- End Voice Recording Logic ---

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      context.read<EntryCubit>().addEntry(currentInput);
      _textController.clear();
      FocusScope.of(context).unfocus(); // Hide keyboard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing entry...'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
    // else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please enter the main entry text.')),
    //   );
    // }
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
                                            // --- Get Cubit instance before await ---
                                            final entryCubit =
                                                listBuilderContext
                                                    .read<EntryCubit>();
                                            // --- Capture Navigator and ScaffoldMessenger before await ---
                                            final navigator = Navigator.of(
                                              dialogContext,
                                            );
                                            final scaffoldMessenger =
                                                ScaffoldMessenger.of(
                                                  dialogContext,
                                                );
                                            // --- End capture ---

                                            bool confirmed =
                                                await _showDeleteCategoryConfirmationDialog(
                                                  listBuilderContext,
                                                  category,
                                                );
                                            if (confirmed && mounted) {
                                              // --- Use the captured Cubit instance ---
                                              entryCubit.deleteCategory(
                                                category,
                                              );
                                              // --- Use captured instances ---
                                              navigator
                                                  .pop(); // Close the dialog
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Category "$category" deleted',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                              // --- End use captured instances ---
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
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Category "$newCategory" added'),
                        ),
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
                        // Check if the main screen state is still mounted
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Entry updated'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    } else {
                      // Optional: Show validation error within dialog if text is empty
                      // Consider showing this error within the dialog itself
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        // Use dialog context
                        const SnackBar(
                          content: Text('Entry text cannot be empty.'),
                          backgroundColor: Colors.red,
                        ),
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
                    : 'No entries yet. Add one!',
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
            padding: const EdgeInsets.only(bottom: 80.0), // Adjust as needed
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
      child: Row(
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
                }).toList(),
              ];

              return DropdownButton<String?>(
                value: _selectedCategoryFilter,
                hint: const Text("Filter"),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategoryFilter = newValue;
                  });
                },
                items: dropdownItems,
              );
            },
          ),
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
                // Microphone Button
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop_circle_outlined : Icons.mic,
                    color:
                        _isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip:
                      _isRecording ? 'Stop Recording' : 'Start Voice Input',
                  iconSize: 30,
                  onPressed: _toggleRecording,
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
                      ScaffoldMessenger.of(
                        context,
                      ).removeCurrentSnackBar(); // Remove any previous snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Entry deleted'),
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              // Re-add the entry if undo is pressed
                              context.read<EntryCubit>().addEntryObject(
                                entryToDelete,
                              );
                            },
                          ),
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
            icon: const Icon(Icons.category),
            tooltip: 'Manage Categories',
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
          ],
        ),
      ),
    );
  }
}
