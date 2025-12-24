import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../entry/entry.dart';
import '../entry/repository/entry_repository.dart';
import '../utils/logger.dart';

class DebugHttpServer {
  final EntryRepository _repository;
  HttpServer? _server;
  static const int port = 8888;

  DebugHttpServer({required EntryRepository repository}) : _repository = repository;

  Future<void> start() async {
    if (!kDebugMode) {
      AppLogger.warn('DebugHttpServer: Not starting - not in debug mode');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      AppLogger.info('DebugHttpServer: Started on http://localhost:$port');
      _server!.listen(_handleRequest);
    } catch (e) {
      AppLogger.error('DebugHttpServer: Failed to start', error: e);
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    AppLogger.info('DebugHttpServer: Stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    try {
      final path = request.uri.path;
      final method = request.method;

      if (method == 'GET' && path == '/health') {
        await _handleHealth(response);
      } else if (method == 'GET' && path == '/entries') {
        await _handleGetEntries(response);
      } else if (method == 'POST' && path == '/entries') {
        await _handlePostEntry(request, response);
      } else if (method == 'POST' && path == '/entries/bulk') {
        await _handlePostBulkEntries(request, response);
      } else {
        _sendError(response, 404, 'Not found');
      }
    } catch (e, stackTrace) {
      AppLogger.error('DebugHttpServer: Request error', error: e, stackTrace: stackTrace);
      _sendError(response, 500, 'Internal server error: $e');
    }
  }

  Future<void> _handleHealth(HttpResponse response) async {
    final categories = _repository.currentCategories.map((c) => c.name).toList();
    _sendSuccess(response, {
      'status': 'ok',
      'port': port,
      'entryCount': _repository.currentEntries.length,
      'categories': categories,
    });
  }

  Future<void> _handleGetEntries(HttpResponse response) async {
    final entries = _repository.currentEntries;
    _sendSuccess(response, {
      'count': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> _handlePostEntry(HttpRequest request, HttpResponse response) async {
    final body = await utf8.decoder.bind(request).join();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _sendError(response, 400, 'Invalid JSON: ${e.message}');
      return;
    }

    // Validate required fields
    if (json['text'] == null || json['text'] is! String || (json['text'] as String).isEmpty) {
      _sendError(response, 400, 'Missing or invalid field: text (must be non-empty string)');
      return;
    }

    // Validate category if provided
    final category = json['category'] as String? ?? 'Misc';
    if (!_isValidCategory(category)) {
      _sendError(response, 400, 'Invalid category: $category. Valid categories: ${_validCategoryNames().join(', ')}');
      return;
    }

    // Validate timestamp format if provided
    if (json['timestamp'] != null) {
      try {
        DateTime.parse(json['timestamp'] as String);
      } on FormatException {
        _sendError(response, 400, 'Invalid timestamp format. Use ISO8601 (e.g., 2025-12-23T10:30:00Z)');
        return;
      }
    }

    // Build entry JSON with defaults
    final entryJson = {
      'text': json['text'],
      'timestamp': json['timestamp'] ?? DateTime.now().toIso8601String(),
      'category': category,
      'isNew': json['isNew'] ?? true,
      'isTask': json['isTask'] ?? false,
      'isCompleted': json['isCompleted'] ?? false,
    };

    final entry = Entry.fromJson(entryJson);
    await _repository.addEntryObject(entry);

    _sendSuccess(response, {'id': entry.id, 'message': 'Entry added'}, statusCode: 201);
  }

  Future<void> _handlePostBulkEntries(HttpRequest request, HttpResponse response) async {
    final body = await utf8.decoder.bind(request).join();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _sendError(response, 400, 'Invalid JSON: ${e.message}');
      return;
    }

    final entriesJson = json['entries'] as List<dynamic>?;
    if (entriesJson == null || entriesJson.isEmpty) {
      _sendError(response, 400, 'Missing or empty entries array');
      return;
    }

    // Validate all entries first
    final entries = <Entry>[];
    for (var i = 0; i < entriesJson.length; i++) {
      if (entriesJson[i] is! Map<String, dynamic>) {
        _sendError(response, 400, 'Entry at index $i must be an object');
        return;
      }
      final entryMap = entriesJson[i] as Map<String, dynamic>;

      if (entryMap['text'] == null || entryMap['text'] is! String || (entryMap['text'] as String).isEmpty) {
        _sendError(response, 400, 'Entry at index $i: text must be non-empty string');
        return;
      }

      final category = entryMap['category'] as String? ?? 'Misc';
      if (!_isValidCategory(category)) {
        _sendError(response, 400, 'Entry at index $i has invalid category: $category');
        return;
      }

      // Validate timestamp format if provided
      if (entryMap['timestamp'] != null) {
        try {
          DateTime.parse(entryMap['timestamp'] as String);
        } on FormatException {
          _sendError(response, 400, 'Entry at index $i has invalid timestamp format. Use ISO8601');
          return;
        }
      }

      // Build entry with defaults and unique timestamp
      final entryJson = {
        'text': entryMap['text'],
        'timestamp': entryMap['timestamp'] ?? DateTime.now().add(Duration(microseconds: i)).toIso8601String(),
        'category': category,
        'isNew': entryMap['isNew'] ?? true,
        'isTask': entryMap['isTask'] ?? false,
        'isCompleted': entryMap['isCompleted'] ?? false,
      };

      entries.add(Entry.fromJson(entryJson));
    }

    // Bulk add
    await _repository.addEntryObjects(entries);

    _sendSuccess(response, {
      'count': entries.length,
      'ids': entries.map((e) => e.id).toList(),
      'message': '${entries.length} entries added',
    }, statusCode: 201);
  }

  bool _isValidCategory(String category) {
    return _repository.currentCategories.any((c) => c.name == category) || category == 'Misc';
  }

  List<String> _validCategoryNames() {
    final names = _repository.currentCategories.map((c) => c.name).toList();
    if (!names.contains('Misc')) names.add('Misc');
    return names;
  }

  void _sendSuccess(HttpResponse response, Map<String, dynamic> data, {int statusCode = 200}) {
    response
      ..statusCode = statusCode
      ..write(jsonEncode(data))
      ..close();
  }

  void _sendError(HttpResponse response, int statusCode, String message) {
    response
      ..statusCode = statusCode
      ..write(jsonEncode({'error': message}))
      ..close();
  }
}
