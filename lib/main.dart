import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'data_store.dart'; // Import the data store

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persistent Input App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Persistent Input & Display'),
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
  static const String _entriesKey =
      'saved_entries'; // Key for SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadEntries(); // Load entries when the widget initializes
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Function to load entries from SharedPreferences
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    // Try reading the list of strings. If it doesn't exist, default to an empty list.
    final savedEntries = prefs.getStringList(_entriesKey) ?? [];
    setState(() {
      allEntries = savedEntries; // Update the global list in data_store
      print('Loaded ${allEntries.length} entries.');
    });
  }

  // Function to save entries to SharedPreferences
  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_entriesKey, allEntries); // Save the current list
    print('Saved ${allEntries.length} entries.');
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      setState(() {
        allEntries.add(currentInput); // Add to the in-memory list
        _textController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry saved!'),
            duration: Duration(seconds: 1),
          ),
        );
      });
      _saveEntries(); // Save the updated list persistently
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter some text.')));
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
          children: <Widget>[
            // Input Area
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter text here',
                hintText: 'Type anything...',
              ),
              onSubmitted: (_) => _handleInput(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _handleInput,
              child: const Text('Save Input'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Saved Entries:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // List Display Area
            Expanded(
              child:
                  allEntries.isEmpty
                      ? const Center(
                        child: Text('No entries yet.'),
                      ) // Show message if list is empty
                      : ListView.builder(
                        itemCount: allEntries.length,
                        itemBuilder: (context, index) {
                          final entry =
                              allEntries[allEntries.length -
                                  1 -
                                  index]; // Show newest first
                          return ListTile(title: Text(entry), dense: true);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
