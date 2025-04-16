import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'entry.dart';
import 'cubit/entry_cubit.dart';
import 'package:collection/collection.dart'; // Import for groupBy

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_US';
    return BlocProvider(
      create: (context) => EntryCubit(),
      child: MaterialApp(
        title: 'Editable Log App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
        ),
        home: const MyHomePage(title: 'Editable Log Entries'),
      ),
    );
  }
}

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      context.read<EntryCubit>().addEntry(currentInput);
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing entry...'),
          duration: Duration(milliseconds: 800),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the main entry text.')),
      );
    }
  }

  // --- Category Management Dialog (Remains the same) ---
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
          (_) => BlocProvider.value(
            value: BlocProvider.of<EntryCubit>(context),
            child: AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BlocBuilder<EntryCubit, EntryState>(
                      builder: (context, state) {
                        if (state.categories.isEmpty) {
                          return const Text('No categories found.');
                        }
                        return Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: state.categories.length,
                            itemBuilder: (context, index) {
                              final category = state.categories[index];
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
                                            bool confirmed =
                                                await _showDeleteCategoryConfirmationDialog(
                                                  context,
                                                  category,
                                                );
                                            if (confirmed) {
                                              context
                                                  .read<EntryCubit>()
                                                  .deleteCategory(category);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Category "$category" deleted',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                              );
                            },
                          ),
                        );
                      },
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
                          if (value.isNotEmpty) {
                            context.read<EntryCubit>().addCustomCategory(value);
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Add Category'),
                  onPressed: () {
                    final newCategory = categoryInputController.text;
                    if (newCategory.isNotEmpty) {
                      context.read<EntryCubit>().addCustomCategory(newCategory);
                      categoryInputController.clear();
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
    final currentState = context.read<EntryCubit>().state;
    final availableCategories = currentState.categories;

    // Ensure the original entry's category is valid, default to Misc if not
    if (!availableCategories.contains(selectedCategory)) {
      selectedCategory = 'Misc';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                    final updatedText = editController.text;
                    if (updatedText.isNotEmpty) {
                      // Create the updated entry object, keeping original timestamp
                      final updatedEntry = Entry(
                        text: updatedText,
                        category: selectedCategory,
                        timestamp: originalEntry.timestamp,
                      );
                      // Call cubit method
                      context.read<EntryCubit>().updateEntry(
                        originalEntry,
                        updatedEntry,
                      );
                      Navigator.of(dialogContext).pop(); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Entry updated'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } else {
                      // Optional: Show validation error within dialog if text is empty
                      ScaffoldMessenger.of(context).showSnackBar(
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Input Area (Remains the same) ---
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
              ),
              onSubmitted: (_) => _handleInput(),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _handleInput,
                child: const Text('Save Log Entry'),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),

            // --- Filter Section (Remains the same) ---
            Padding(
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
                        return const SizedBox.shrink();
                      }
                      List<DropdownMenuItem<String?>> dropdownItems = [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("All Categories"),
                        ),
                      ];
                      List<String> sortedCategories = List.from(
                        state.categories,
                      )..sort();
                      dropdownItems.addAll(
                        sortedCategories.map((String category) {
                          return DropdownMenuItem<String?>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                      );
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
            ),

            // --- List Display Area - Modified for Editing ---
            Expanded(
              child: BlocBuilder<EntryCubit, EntryState>(
                builder: (context, state) {
                  if (state.isLoading && state.entries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<Entry> filteredEntries;
                  if (_selectedCategoryFilter == null) {
                    filteredEntries = state.entries;
                  } else {
                    filteredEntries =
                        state.entries
                            .where(
                              (entry) =>
                                  entry.category == _selectedCategoryFilter,
                            )
                            .toList();
                  }

                  filteredEntries.sort(
                    (a, b) => b.timestamp.compareTo(a.timestamp),
                  );

                  if (filteredEntries.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedCategoryFilter != null
                            ? 'No entries found for category: "$_selectedCategoryFilter"'
                            : 'No entries yet. Add one!',
                      ),
                    );
                  }

                  final List<dynamic> listItems = [];
                  final groupedEntries = groupBy<Entry, DateTime>(
                    filteredEntries,
                    (entry) => DateTime(
                      entry.timestamp.year,
                      entry.timestamp.month,
                      entry.timestamp.day,
                    ),
                  );
                  groupedEntries.forEach((date, entriesOnDate) {
                    listItems.add(date);
                    listItems.addAll(entriesOnDate);
                  });

                  return ListView.builder(
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];

                      if (item is DateTime) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            _formatDateHeader(item),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      } else if (item is Entry) {
                        final entry = item;
                        bool isProcessing = entry.category == 'Processing...';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 2.0,
                            horizontal: 0,
                          ),
                          child: ListTile(
                            title: Text(entry.text),
                            subtitle: Text(
                              '${_timeFormatter.format(entry.timestamp)} - ${entry.category}',
                              style: TextStyle(
                                color:
                                    isProcessing
                                        ? Colors.orange
                                        : Colors.grey[700],
                              ),
                            ),
                            // Updated Trailing to include Edit button
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isProcessing)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                      ),
                                    ),
                                  ),
                                // Edit Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Edit Entry',
                                  visualDensity:
                                      VisualDensity
                                          .compact, // Make it slightly smaller
                                  onPressed:
                                      isProcessing
                                          ? null
                                          : () {
                                            // Disable edit while processing
                                            _showEditEntryDialog(
                                              context,
                                              entry,
                                            );
                                          },
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete Entry',
                                  visualDensity:
                                      VisualDensity
                                          .compact, // Make it slightly smaller
                                  onPressed:
                                      isProcessing
                                          ? null
                                          : () {
                                            final entryToDelete = entry;
                                            context
                                                .read<EntryCubit>()
                                                .deleteEntry(entryToDelete);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).removeCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Entry deleted',
                                                ),
                                                duration: const Duration(
                                                  seconds: 4,
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Undo',
                                                  onPressed: () {
                                                    context
                                                        .read<EntryCubit>()
                                                        .addEntryObject(
                                                          entryToDelete,
                                                        );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                ),
                              ],
                            ),
                            dense: true,
                          ),
                        );
                      }
                      return Container();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
