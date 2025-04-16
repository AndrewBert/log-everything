import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc packages
import 'package:intl/intl.dart';
// Remove direct import of shared_preferences, Cubit handles it
// Remove import of data_store.dart
import 'entry.dart';
import 'cubit/entry_cubit.dart'; // Import the Cubit

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_US';
    // Provide the EntryCubit to the widget tree
    return BlocProvider(
      create:
          (context) =>
              EntryCubit()..loadEntries(), // Create and load initial data
      child: MaterialApp(
        title: 'Cubit Input App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Cubit Input'),
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
  final TextEditingController _categoryController = TextEditingController();
  final DateFormat _formatter = DateFormat('yyyy-MM-dd HH:mm');

  // Remove initState loading, Cubit handles it now
  // Remove _loadEntries and _saveEntries methods

  @override
  void dispose() {
    _textController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // Handle input by calling the Cubit's addEntry method
  void _handleInput() {
    final String currentInput = _textController.text;
    final String currentCategory = _categoryController.text;

    if (currentInput.isNotEmpty) {
      // Access the Cubit and call its method
      context.read<EntryCubit>().addEntry(currentInput, currentCategory);

      // Clear controllers after adding
      _textController.clear();
      _categoryController.clear();

      // Show feedback (SnackBar is fine here, or could be handled via BlocListener)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Entry added via Cubit!'), // Simplified message
          duration: Duration(seconds: 1),
        ),
      );
      // Remove setState, BlocBuilder handles UI updates
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the main entry text.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Input Area (remains the same)
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Category (optional)',
                hintText: 'e.g., Work, Food, Exercise (defaults to General)',
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

            // List Display Area - Now wrapped in BlocBuilder
            Expanded(
              // Use BlocBuilder to listen to EntryCubit state changes
              child: BlocBuilder<EntryCubit, List<Entry>>(
                builder: (context, entries) {
                  // `entries` is the current state (List<Entry>)
                  if (entries.isEmpty) {
                    return const Center(child: Text('No entries yet.'));
                  }
                  // Build the ListView using the state from the Cubit
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      // Access entries directly from the state
                      final entry =
                          entries[entries.length - 1 - index]; // Newest first
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(entry.text),
                          subtitle: Text(
                            '${entry.category} - ${_formatter.format(entry.timestamp)}',
                            style: TextStyle(color: Colors.grey[700]),
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
