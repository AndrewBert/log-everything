import 'package:flutter/material.dart';

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
      home: const MyHomePage(title: 'Basic Input'),
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
  // Controller to manage the text field's input
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _textController.dispose();
    super.dispose();
  }

  void _handleInput() {
    final String currentInput = _textController.text;
    if (currentInput.isNotEmpty) {
      print('User Input: $currentInput');
      // You can add further processing here, like calling the input_handler
      // Or clearing the field after processing:
      // _textController.clear();
    } else {
      print('Input field is empty.');
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
        // Add padding around the content
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Arrange widgets vertically
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: <Widget>[
            TextField(
              controller: _textController, // Link controller to the text field
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter text here',
                hintText: 'Type anything...',
              ),
              onSubmitted:
                  (_) => _handleInput(), // Optional: handle input on submit
            ),
            const SizedBox(height: 20), // Add some space between widgets
            ElevatedButton(
              onPressed: _handleInput, // Call _handleInput when pressed
              child: const Text('Submit Input'),
            ),
          ],
        ),
      ),
      // Removed the FloatingActionButton
    );
  }
}
