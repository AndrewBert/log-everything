import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'entry.dart';
import 'cubit/entry_cubit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_US';
    return BlocProvider(
      create: (context) => EntryCubit()..loadEntries(),
      child: MaterialApp(
        title: 'Smart Input App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Smart Input'),
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
  // Only one controller needed now
  final TextEditingController _textController = TextEditingController();
  final DateFormat _formatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void dispose() {
    _textController.dispose();
    // No category controller to dispose
    super.dispose();
  }

  // Handle input: only pass text to the Cubit
  void _handleInput() {
    final String currentInput = _textController.text;

    if (currentInput.isNotEmpty) {
      // Call cubit method with only the text
      context.read<EntryCubit>().addEntry(currentInput);

      _textController.clear();

      // Feedback can be more generic now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry added!'),
          duration: Duration(seconds: 1),
        ),
      );
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
            // Input Area - Only the main text field remains
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
              ),
              onSubmitted: (_) => _handleInput(), // Submit on enter
              textInputAction: TextInputAction.done,
            ),
            // Removed category TextField
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

            // List Display Area - Uses BlocBuilder (remains the same)
            Expanded(
              child: BlocBuilder<EntryCubit, List<Entry>>(
                builder: (context, entries) {
                  if (entries.isEmpty) {
                    return const Center(child: Text('No entries yet.'));
                  }
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[entries.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(entry.text),
                          subtitle: Text(
                            // Category is now determined by the (simulated) LLM
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
