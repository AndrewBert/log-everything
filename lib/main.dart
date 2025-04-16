import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'entry.dart';
import 'cubit/entry_cubit.dart';

Future<void> main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await dotenv.load(fileName: ".env"); // Load the .env file
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_US';
    return BlocProvider(
      // Pass dotenv to the cubit if needed, or load within cubit
      create: (context) => EntryCubit()..loadEntries(),
      child: MaterialApp(
        title: 'OpenAI Input App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'OpenAI Input'),
      ),
    );
  }
}

// --- Rest of MyHomePage and _MyHomePageState remain the same ---

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
          content: Text('Processing entry...'), // Indicate processing
          duration: Duration(milliseconds: 800),
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
              child: BlocBuilder<EntryCubit, List<Entry>>(
                builder: (context, entries) {
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('No entries yet. Add one!'),
                    );
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
