import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'dart:convert'; // Needed for jsonDecode exception handling
import 'data_store.dart'; // Import the data store
import 'entry.dart'; // Import the Entry class

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_US';
    return MaterialApp(
      title: 'Timestamped Input App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Input with Timestamps'),
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
      'saved_entries_v2'; // Key for SharedPreferences
  final DateFormat _formatter = DateFormat(
    'yyyy-MM-dd HH:mm',
  ); // Date formatter

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Load entries with error handling for incompatible data
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    List<Entry> loadedEntries = [];
    bool loadSuccess = true;

    try {
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson.map((jsonString) {
              // This is where parsing happens and might fail
              return Entry.fromJsonString(jsonString);
            }).toList();
      }
      print('Successfully loaded ${loadedEntries.length} entries.');
    } catch (e) {
      print(
        'Error loading entries: $e. Clearing potentially incompatible data.',
      );
      loadSuccess = false;
      // Clear the invalid data associated with the key
      await prefs.remove(_entriesKey);
      // Ensure the in-memory list is also empty
      loadedEntries = [];
    }

    // Update the state outside the try-catch block
    setState(() {
      allEntries = loadedEntries;
    });

    // Optional: Show feedback if data was cleared
    if (!loadSuccess && mounted) {
      // Check if the widget is still in the tree
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previous data format incompatible. Cleared storage.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Save entries: Convert Entry objects to JSON strings before saving
  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson =
          allEntries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Saved ${allEntries.length} entries.');
    } catch (e) {
      print('Error saving entries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      final newEntry = Entry(text: currentInput, timestamp: DateTime.now());

      setState(() {
        allEntries.add(newEntry);
        _textController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry saved!'),
            duration: Duration(seconds: 1),
          ),
        );
      });
      _saveEntries(); // Save the updated list
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
                      ? const Center(child: Text('No entries yet.'))
                      : ListView.builder(
                        itemCount: allEntries.length,
                        itemBuilder: (context, index) {
                          final entry =
                              allEntries[allEntries.length - 1 - index];
                          return ListTile(
                            title: Text(entry.text),
                            subtitle: Text(
                              _formatter.format(entry.timestamp),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            dense: true,
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
