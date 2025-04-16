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
        title: 'Grouped Log App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          // Optional: Add a divider theme for headers
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
        ),
        home: const MyHomePage(title: 'Grouped Log Entries'),
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
  // Keep existing formatter for entry time
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
            duration: Duration(milliseconds: 800)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the main entry text.')),
      );
    }
  }

  // --- Category Management Dialog (Remains the same) ---
  Future<bool> _showDeleteCategoryConfirmationDialog(BuildContext context, String category) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete Category'),
          content: Text('''Are you sure you want to delete the category "$category"?
Entries using this category will be moved to "Misc".'''),
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
    ) ?? false;
  }

  void _showManageCategoriesDialog() {
    final categoryInputController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
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
                              style: TextStyle(color: isMisc ? Colors.grey : null),
                            ),
                            dense: true,
                            trailing: isMisc
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
                                  tooltip: 'Delete Category',
                                  onPressed: () async {
                                     bool confirmed = await _showDeleteCategoryConfirmationDialog(context, category);
                                      if (confirmed) {
                                          context.read<EntryCubit>().deleteCategory(category);
                                           ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Category "$category" deleted'), duration: Duration(seconds: 2)),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  // --- Helper to Format Date Headers ---
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
      // Use a more complete format for older dates
      return DateFormat.yMMMd().format(date); // e.g., Oct 27, 2023
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
                  const Text('Saved Entries:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  BlocBuilder<EntryCubit, EntryState>(
                    builder: (context, state) {
                       // Build dropdown only if categories are loaded
                      if (state.categories.isEmpty && !state.isLoading) {
                         return const SizedBox.shrink(); // Hide if no categories
                      }
                       List<DropdownMenuItem<String?>> dropdownItems = [
                        const DropdownMenuItem<String?>(value: null, child: Text("All Categories")),
                      ];
                      List<String> sortedCategories = List.from(state.categories)..sort();
                      dropdownItems.addAll(
                        sortedCategories.map((String category) {
                          return DropdownMenuItem<String?>(value: category, child: Text(category));
                        }).toList(),
                      );
                      return DropdownButton<String?>(
                        value: _selectedCategoryFilter,
                        hint: const Text("Filter"), // Shorter hint
                        onChanged: (String? newValue) {
                          setState(() { _selectedCategoryFilter = newValue; });
                        },
                        items: dropdownItems,
                      );
                    },
                  )
                ],
              ),
            ),

            // --- List Display Area - Modified for Grouping ---
            Expanded(
              child: BlocBuilder<EntryCubit, EntryState>(
                builder: (context, state) {
                  if (state.isLoading && state.entries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1. Filter entries first
                  final List<Entry> filteredEntries;
                  if (_selectedCategoryFilter == null) {
                    filteredEntries = state.entries;
                  } else {
                    filteredEntries = state.entries
                        .where((entry) => entry.category == _selectedCategoryFilter)
                        .toList();
                  }

                   // Ensure entries are sorted newest first before grouping
                   // (Assuming Cubit might not always guarantee order after complex ops)
                  filteredEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  if (filteredEntries.isEmpty) {
                    return Center(
                      child: Text(_selectedCategoryFilter != null
                          ? 'No entries found for category: "$_selectedCategoryFilter"'
                          : 'No entries yet. Add one!'),
                    );
                  }

                  // 2. Group filtered entries by date
                  // Using collection package's groupBy
                  final groupedEntries = groupBy<Entry, DateTime>(
                    filteredEntries,
                    (entry) => DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day),
                  );

                  // 3. Create a flat list with Headers and Entries
                  final List<dynamic> listItems = [];
                  groupedEntries.forEach((date, entriesOnDate) {
                    listItems.add(date); // Add date header
                    listItems.addAll(entriesOnDate); // Add entries for that date
                  });


                  // 4. Build the ListView with mixed item types
                  return ListView.builder(
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];

                      // If item is a DateTime, show a header
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
                      }
                      // If item is an Entry, show the entry card
                      else if (item is Entry) {
                         final entry = item;
                         bool isProcessing = entry.category == 'Processing...';
                         return Card(
                           margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 0), // Reduced margin
                           child: ListTile(
                             title: Text(entry.text),
                             // Changed subtitle to show Time and Category
                             subtitle: Text(
                               '${_timeFormatter.format(entry.timestamp)} - ${entry.category}',
                               style: TextStyle(color: isProcessing ? Colors.orange : Colors.grey[700]),
                             ),
                             trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isProcessing)
                                    const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.0)
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: 'Delete Entry',
                                    onPressed: isProcessing ? null : () {
                                      final entryToDelete = entry;
                                      context.read<EntryCubit>().deleteEntry(entryToDelete);
                                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Entry deleted'),
                                          duration: const Duration(seconds: 4),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
                                              context.read<EntryCubit>().addEntryObject(entryToDelete);
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
                      // Should not happen, but return empty container as fallback
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
