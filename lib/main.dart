import 'package:flutter/material.dart';
import 'data_store.dart'; // Import the data store

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Input App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Input & Display'),
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      setState(() {
        // Call setState to trigger UI rebuild
        allEntries.add(currentInput);
        print('Saved entry: $currentInput');
        print('Current entries: $allEntries');

        _textController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry saved!'),
            duration: Duration(seconds: 1),
          ),
        );
      });
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
        // Use a Column to layout input area and list vertically
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
            const SizedBox(height: 10), // Reduced space
            ElevatedButton(
              onPressed: _handleInput,
              child: const Text('Save Input'),
            ),
            const SizedBox(height: 20), // Space before the list
            // Divider
            const Divider(),

            // Header for the list
            const Text(
              'Saved Entries:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // List Display Area
            Expanded(
              // Allows the ListView to take available space
              child: ListView.builder(
                itemCount: allEntries.length,
                itemBuilder: (context, index) {
                  // Get the entry in reverse order to show newest first
                  final entry = allEntries[allEntries.length - 1 - index];
                  return ListTile(
                    title: Text(entry),
                    dense: true, // Make list items a bit smaller
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
