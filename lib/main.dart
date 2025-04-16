import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'entry.dart';
import 'cubit/entry_cubit.dart'; // Import the Cubit and its State

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
        title: 'Custom Category App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Categorized Input & Management'),
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
  final DateFormat _formatter = DateFormat('yyyy-MM-dd HH:mm');
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
                              return ListTile(
                                title: Text(category),
                                dense: true,
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
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
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

  // Function to show confirmation dialog before deleting
  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    Entry entry,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: Text(
                'Are you sure you want to delete this entry?\n"${entry.text}"',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false); // Return false
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true); // Return true
                  },
                ),
              ],
            );
          },
        ) ??
        false; // Return false if dialog is dismissed
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
                      List<DropdownMenuItem<String?>> dropdownItems = [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("All Categories"),
                        ),
                      ];
                      dropdownItems.addAll(
                        state.categories.map((String category) {
                          return DropdownMenuItem<String?>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                      );
                      return DropdownButton<String?>(
                        value: _selectedCategoryFilter,
                        hint: const Text("Filter by Category"),
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

                  if (filteredEntries.isEmpty) {
                    if (_selectedCategoryFilter != null) {
                      return Center(
                        child: Text(
                          'No entries found for category: "$_selectedCategoryFilter"',
                        ),
                      );
                    } else {
                      return const Center(
                        child: Text('No entries yet. Add one!'),
                      );
                    }
                  }

                  return ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry =
                          filteredEntries[filteredEntries.length - 1 - index];
                      bool isProcessing = entry.category == 'Processing...';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(entry.text),
                          subtitle: Text(
                            '${entry.category} - ${_formatter.format(entry.timestamp)}',
                            style: TextStyle(
                              color:
                                  isProcessing
                                      ? Colors.orange
                                      : Colors.grey[700],
                            ),
                          ),
                          // Modify trailing to include delete button
                          trailing: Row(
                            // Use Row to combine processing indicator and delete button
                            mainAxisSize:
                                MainAxisSize
                                    .min, // Prevent Row from taking max width
                            children: [
                              if (isProcessing)
                                const SizedBox(
                                  width: 24, // Slightly larger for tap area
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                ),
                              // Delete button
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete Entry',
                                onPressed:
                                    isProcessing
                                        ? null
                                        : () async {
                                          // Disable delete while processing
                                          // Show confirmation dialog
                                          bool confirmed =
                                              await _showDeleteConfirmationDialog(
                                                context,
                                                entry,
                                              );
                                          if (confirmed) {
                                            // Call cubit method if confirmed
                                            context
                                                .read<EntryCubit>()
                                                .deleteEntry(entry);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Entry deleted'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                              ),
                            ],
                          ),
                          dense: true,
                        ),
                      );
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
