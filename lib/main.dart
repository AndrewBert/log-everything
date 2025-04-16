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

  // --- UI for Category Management ---
  void _showManageCategoriesDialog() {
    final categoryInputController = TextEditingController();

    showDialog(
      context: context,
      // Use BlocProvider.value to pass the existing Cubit instance to the dialog subtree
      builder:
          (_) => BlocProvider.value(
            value: BlocProvider.of<EntryCubit>(
              context,
            ), // Pass the existing cubit
            child: AlertDialog(
              title: const Text('Manage Categories'),
              // Make content scrollable in case of many categories
              content: SizedBox(
                width: double.maxFinite, // Use available width
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Take minimum vertical space
                  children: [
                    // Listen to the Cubit state for categories
                    BlocBuilder<EntryCubit, EntryState>(
                      builder: (context, state) {
                        if (state.categories.isEmpty) {
                          return const Text('No categories found.');
                        }
                        // Display categories in a scrollable list
                        return Expanded(
                          child: ListView.builder(
                            shrinkWrap: true, // Important for Column layout
                            itemCount: state.categories.length,
                            itemBuilder: (context, index) {
                              final category = state.categories[index];
                              return ListTile(
                                title: Text(category),
                                dense: true,
                                // Optional: Add delete button here later
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    // Input field to add a new category
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
                      // Call the cubit method to add
                      context.read<EntryCubit>().addCustomCategory(newCategory);
                      categoryInputController
                          .clear(); // Clear field after adding
                      // Optionally, keep the dialog open or close it
                      // Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Saved Entries:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: BlocBuilder<EntryCubit, EntryState>(
                builder: (context, state) {
                  if (state.isLoading && state.entries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.entries.isEmpty) {
                    return const Center(
                      child: Text('No entries yet. Add one!'),
                    );
                  }
                  return ListView.builder(
                    itemCount: state.entries.length,
                    itemBuilder: (context, index) {
                      final entry =
                          state.entries[state.entries.length - 1 - index];
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
                          trailing:
                              isProcessing
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                  : null,
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
