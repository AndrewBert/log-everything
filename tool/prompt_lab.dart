// ignore_for_file: avoid_print
// CP: CLI tool for rapid prompt iteration on chat suggestions
// Usage: dart run tool/prompt_lab.dart
// Usage: dart run tool/prompt_lab.dart --mock  (uses mock data without debug API)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const debugApiUrl = 'http://localhost:8888/entries';
const openAiApiUrl = 'https://api.openai.com/v1/responses';
const modelId = 'gpt-5-mini';

Future<void> main(List<String> args) async {
  print('═══ Prompt Lab ═══\n');

  // 1. Load API key from .env
  final apiKey = await _loadApiKey();
  if (apiKey == null) {
    print('❌ Error: Could not load OPENAI_API_KEY from .env');
    exit(1);
  }

  // 2. Fetch entries from debug API or use mock data
  final useMock = args.contains('--mock');
  final entries = useMock ? _getMockEntries() : await _fetchEntries();

  if (entries == null) {
    print('❌ Error: Could not fetch entries from debug API');
    print('   Make sure the app is running in debug mode');
    print('   Or use --mock flag to run with mock data');
    exit(1);
  }

  final totalCount = entries['count'] as int? ?? 0;
  final entryList = entries['entries'] as List? ?? [];
  final usedCount = entryList.length > 20 ? 20 : entryList.length;

  if (useMock) {
    print('Using mock data ($totalCount entries)\n');
  } else {
    print('Fetched $totalCount entries, using $usedCount most recent\n');
  }

  if (usedCount < 5) {
    print('⚠️  Warning: Only $usedCount entries found. Need at least 5 for good suggestions.');
  }

  // 3. Load and populate prompt template
  final template = await _loadTemplate();
  if (template == null) {
    print('❌ Error: Could not load tool/prompt_template.txt');
    exit(1);
  }

  final formattedEntries = _formatEntries(entryList.take(20).toList());
  final dateString = DateTime.now().toLocal().toString().split(' ')[0];
  final prompt = template.replaceAll('{{DATE}}', dateString).replaceAll('{{ENTRIES}}', formattedEntries);

  // 4. Call OpenAI API
  print('Calling OpenAI ($modelId)...\n');
  final suggestions = await _callOpenAi(apiKey, prompt);

  if (suggestions == null) {
    print('❌ Error: Failed to get suggestions from OpenAI');
    exit(1);
  }

  // 5. Display results
  print('─── Generated Suggestions ───');
  for (var i = 0; i < suggestions.length; i++) {
    print('${i + 1}. "${suggestions[i]}"');
  }
  print('');
}

Future<String?> _loadApiKey() async {
  try {
    final envFile = File('.env');
    if (!await envFile.exists()) {
      return null;
    }
    final contents = await envFile.readAsString();
    for (final line in contents.split('\n')) {
      if (line.startsWith('OPENAI_API_KEY=')) {
        return line.substring('OPENAI_API_KEY='.length).trim();
      }
    }
    return null;
  } catch (e) {
    print('Error reading .env: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> _fetchEntries() async {
  try {
    final response = await http.get(Uri.parse(debugApiUrl));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    print('Debug API returned status ${response.statusCode}');
    return null;
  } catch (e) {
    print('Error connecting to debug API: $e');
    return null;
  }
}

// CP: Mock data for testing prompts without the debug API
Map<String, dynamic> _getMockEntries() {
  final now = DateTime.now();
  String ts(int daysAgo, int hour) =>
      now.subtract(Duration(days: daysAgo)).copyWith(hour: hour, minute: 0).toIso8601String();

  final entries = [
    // Reading/Learning - heavy pattern
    {
      'text': 'Read 30 pages of Atomic Habits',
      'category': 'Learning',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(0, 22),
    },
    {
      'text': 'Finished chapter on habit stacking',
      'category': 'Learning',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(1, 21),
    },
    {
      'text': 'Started learning Spanish on Duolingo',
      'category': 'Learning',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(2, 19),
    },
    {
      'text': 'Watched YouTube tutorial on guitar chords',
      'category': 'Learning',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(3, 20),
    },

    // Exercise variety
    {
      'text': 'Yoga session - 45 minutes',
      'category': 'Health',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(0, 7),
    },
    {
      'text': 'Evening walk with dog - 2 miles',
      'category': 'Health',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(1, 18),
    },
    {
      'text': 'Tried new HIIT workout',
      'category': 'Health',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(2, 6),
    },

    // Social/relationships
    {
      'text': 'Coffee with Sarah, talked about her new job',
      'category': 'Social',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(0, 10),
    },
    {
      'text': 'Called mom for her birthday',
      'category': 'Social',
      'isTask': true,
      'isCompleted': true,
      'timestamp': ts(1, 14),
    },
    {
      'text': 'Game night at Tom\'s place',
      'category': 'Social',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(3, 19),
    },

    // Creative/hobbies
    {
      'text': 'Practiced guitar - learned G chord',
      'category': 'Hobbies',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(0, 20),
    },
    {
      'text': 'Sketched landscape in park',
      'category': 'Hobbies',
      'isTask': false,
      'isCompleted': false,
      'timestamp': ts(2, 15),
    },

    // Misc tasks
    {
      'text': 'Book vet appointment for Max',
      'category': 'Tasks',
      'isTask': true,
      'isCompleted': false,
      'timestamp': ts(0, 9),
    },
    {'text': 'Return library books', 'category': 'Tasks', 'isTask': true, 'isCompleted': true, 'timestamp': ts(1, 11)},
    {
      'text': 'Fix leaky kitchen faucet',
      'category': 'Tasks',
      'isTask': true,
      'isCompleted': false,
      'timestamp': ts(4, 8),
    },
  ];

  return {
    'count': entries.length,
    'entries': entries,
  };
}

Future<String?> _loadTemplate() async {
  try {
    final templateFile = File('tool/prompt_template.txt');
    if (!await templateFile.exists()) {
      return null;
    }
    return await templateFile.readAsString();
  } catch (e) {
    print('Error reading template: $e');
    return null;
  }
}

String _formatEntries(List<dynamic> entries) {
  // CP: Match the format used in ai_service.dart
  return entries
      .map((e) {
        final text = e['text'] as String? ?? '';
        final category = e['category'] as String? ?? 'Unknown';
        final isTask = e['isTask'] as bool? ?? false;
        final isCompleted = e['isCompleted'] as bool? ?? false;
        final timestamp = e['timestamp'] as String? ?? '';
        return '- [$category] $text (task: $isTask, completed: $isCompleted, date: $timestamp)';
      })
      .join('\n');
}

Future<List<String>?> _callOpenAi(String apiKey, String prompt) async {
  try {
    final requestBody = {
      'model': modelId,
      'input': [
        {
          'role': 'system',
          'content':
              "You generate short, personalized chat prompts for a personal logging app. Keep suggestions concise and relevant to the user's actual data.",
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'text': {
        'format': {'type': 'json_object'},
      },
    };

    final response = await http.post(
      Uri.parse(openAiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      print('OpenAI API error: ${response.statusCode}');
      print(response.body);
      return null;
    }

    final responseBody = jsonDecode(response.body);

    if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
      print('OpenAI request failed: ${responseBody['error']}');
      return null;
    }

    // CP: Parse response structure matching ai_service.dart pattern
    if (responseBody['output'] != null &&
        responseBody['output'] is List &&
        (responseBody['output'] as List).isNotEmpty) {
      Map<String, dynamic>? messageOutput;
      for (final item in responseBody['output'] as List) {
        if (item is Map<String, dynamic> && item['type'] == 'message') {
          messageOutput = item;
          break;
        }
      }

      if (messageOutput != null) {
        final content = messageOutput['content'];
        if (content != null && content is List && content.isNotEmpty) {
          for (final item in content) {
            if (item is Map<String, dynamic> && item['type'] == 'output_text' && item['text'] != null) {
              final json = jsonDecode(item['text'] as String);
              final prompts = (json['prompts'] as List?)?.cast<String>() ?? [];
              return prompts.take(3).toList();
            }
          }
        }
      }
    }

    print('Unexpected response format');
    return null;
  } catch (e) {
    print('Error calling OpenAI: $e');
    return null;
  }
}
