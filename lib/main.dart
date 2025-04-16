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
      title: 'Categorized Input App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Categorized Input'),
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
  // Controllers for both input fields
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _categoryController =
      TextEditingController(); // Controller for category

  static const String _entriesKey = 'saved_entries_v3_categorized';
  final DateFormat _formatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    // Dispose both controllers
    _textController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // Load entries function (remains the same)
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    List<Entry> loadedEntries = [];
    bool loadSuccess = true;

    try {
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson.map((jsonString) {
              return Entry.fromJsonString(jsonString);
            }).toList();
      }
      print('Successfully loaded ${loadedEntries.length} categorized entries.');
    } catch (e) {
      print(
        'Error loading entries: $e. Clearing potentially incompatible data for key $_entriesKey.',
      );
      loadSuccess = false;
      await prefs.remove(_entriesKey);
      loadedEntries = [];
    }

    setState(() {
      allEntries = loadedEntries;
    });

    if (!loadSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared incompatible data for key: $_entriesKey.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Save entries function (remains the same)
  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson =
          allEntries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Saved ${allEntries.length} categorized entries.');
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

  // Handle input, now including the category from its text field
  void _handleInput() {
    final String currentInput = _textController.text;
    final String currentCategory =
        _categoryController.text.trim(); // Get category and trim whitespace

    if (currentInput.isNotEmpty) {
      // Use entered category, default to 'General' if empty
      final String categoryToSave =
          currentCategory.isNotEmpty ? currentCategory : 'General';

      final newEntry = Entry(
        text: currentInput,
        timestamp: DateTime.now(),
        category: categoryToSave,
      );

      setState(() {
        allEntries.add(newEntry);
        _textController.clear();
        _categoryController.clear(); // Clear category field too

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry saved to $categoryToSave!'),
            duration: Duration(seconds: 1),
          ),
        );
      });
      _saveEntries();
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
            // Input Area
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter log entry here',
                hintText: 'What happened?...',
              ),
              // Move focus to category field on submit
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            // Category Input Field
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Category (optional)',
                hintText: 'e.g., Work, Food, Exercise (defaults to General)',
              ),
              // Submit the form on submit
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
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
