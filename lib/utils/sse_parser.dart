import 'dart:async';
import 'dart:convert';

/// Parser for Server-Sent Events (SSE) streams
/// Handles parsing of SSE format according to the W3C specification
class SseParser {
  final _buffer = StringBuffer();
  final _eventController = StreamController<SseEvent>();
  
  // Current event being built
  String? _currentEventType;
  final _currentDataLines = <String>[];
  
  Stream<SseEvent> get events => _eventController.stream;
  
  /// Process a chunk of SSE data
  void processChunk(String chunk) {
    _buffer.write(chunk);
    _processBuffer();
  }
  
  /// Process the buffer, extracting complete events
  void _processBuffer() {
    final bufferString = _buffer.toString();
    final lines = bufferString.split('\n');
    
    // Keep the last line if it doesn't end with newline (partial line)
    final isLastLinePartial = !bufferString.endsWith('\n');
    final linesToProcess = isLastLinePartial ? lines.length - 1 : lines.length;
    
    // Clear buffer and keep partial line if needed
    _buffer.clear();
    if (isLastLinePartial && lines.isNotEmpty) {
      _buffer.write(lines.last);
    }
    
    // Process complete lines
    for (int i = 0; i < linesToProcess; i++) {
      _processLine(lines[i]);
    }
  }
  
  /// Process a single line according to SSE spec
  void _processLine(String line) {
    // Remove trailing \r if present (for \r\n line endings)
    if (line.endsWith('\r')) {
      line = line.substring(0, line.length - 1);
    }
    
    // Empty line signals end of event
    if (line.isEmpty) {
      _dispatchEvent();
      return;
    }
    
    // Comment line (starts with :)
    if (line.startsWith(':')) {
      return; // Ignore comments
    }
    
    // Parse field and value
    final colonIndex = line.indexOf(':');
    String field;
    String value;
    
    if (colonIndex == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colonIndex);
      value = line.substring(colonIndex + 1);
      // Remove leading space from value if present
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
    }
    
    // Process based on field name
    switch (field) {
      case 'event':
        _currentEventType = value;
        break;
      case 'data':
        _currentDataLines.add(value);
        break;
      case 'id':
      case 'retry':
        // These fields are not used in our implementation
        break;
    }
  }
  
  /// Dispatch the current event if we have data
  void _dispatchEvent() {
    if (_currentDataLines.isEmpty) {
      // Reset for next event
      _currentEventType = null;
      return;
    }
    
    // Join data lines with newlines
    final data = _currentDataLines.join('\n');
    
    // Create and emit event
    final event = SseEvent(
      type: _currentEventType ?? 'message',
      data: data,
    );
    
    _eventController.add(event);
    
    // Reset for next event
    _currentEventType = null;
    _currentDataLines.clear();
  }
  
  /// Close the parser and clean up resources
  void close() {
    // Process any remaining buffer content
    _processBuffer();
    
    // If we have partial data, treat it as complete and dispatch
    if (_currentDataLines.isNotEmpty) {
      _dispatchEvent();
    }
    
    // Close the stream
    _eventController.close();
  }
}

/// Represents a single SSE event
class SseEvent {
  final String type;
  final String data;
  
  SseEvent({required this.type, required this.data});
  
  /// Try to parse the data as JSON
  Map<String, dynamic>? get jsonData {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
  
  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}

