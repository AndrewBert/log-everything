/// Represents the processing lifecycle of an entry.
///
/// Entries start as [pending] when first submitted, transition to [processing]
/// during AI categorization, and end at [completed] or [failed].
enum ProcessingState {
  /// Entry has been saved locally and is awaiting AI processing.
  pending,

  /// Entry is currently being processed by AI service.
  processing,

  /// Entry has been successfully processed and categorized.
  completed,

  /// Processing failed after max retries. Entry saved with fallback category.
  failed,
}
