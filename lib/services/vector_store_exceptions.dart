// CP: Custom exception for vector store operations.
class VectorStoreSyncException implements Exception {
  final String message;
  final dynamic underlyingError;

  VectorStoreSyncException(this.message, {this.underlyingError});

  @override
  String toString() {
    if (underlyingError != null) {
      return 'VectorStoreSyncException: $message - Underlying error: $underlyingError';
    }
    return 'VectorStoreSyncException: $message';
  }
}
