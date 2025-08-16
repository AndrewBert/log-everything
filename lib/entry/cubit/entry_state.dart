part of 'entry_cubit.dart';

// Extend Equatable
class EntryState extends Equatable {
  // Use List<Category> for categories to support descriptions
  final List<Category> categories;
  final bool isLoading;
  final String? lastErrorMessage;
  final String? filterCategory;
  final List<dynamic> displayListItems;
  // Add recentCategories based on entry usage
  final List<String> recentCategories;
  // CP: Add editing state properties
  final Entry? editingEntry;
  final bool isEditingMode;
  final bool? editingIsTask;
  // CP: Add context menu state properties
  final Entry? contextMenuEntry;
  // CP: Add split notification for toast messages
  final String? splitNotification;
  // CC: Add undo split information
  final String? undoBatchId;
  final String? undoOriginalText;

  const EntryState({
    this.categories = const [],
    this.isLoading = false,
    this.lastErrorMessage,
    this.filterCategory,
    this.displayListItems = const [],
    this.recentCategories = const [],
    this.editingEntry,
    this.isEditingMode = false,
    this.editingIsTask,
    this.contextMenuEntry,
    this.splitNotification,
    this.undoBatchId,
    this.undoOriginalText,
  });

  // Implement props getter
  @override
  List<Object?> get props => [
    categories,
    isLoading,
    lastErrorMessage,
    filterCategory,
    displayListItems,
    recentCategories,
    editingEntry,
    isEditingMode,
    editingIsTask,
    contextMenuEntry,
    splitNotification,
    undoBatchId,
    undoOriginalText,
  ];

  // copyWith remains the same, but without entries
  EntryState copyWith({
    List<Category>? categories,
    bool? isLoading,
    String? lastErrorMessage,
    String? filterCategory,
    List<dynamic>? displayListItems,
    List<String>? recentCategories,
    Entry? editingEntry,
    bool? isEditingMode,
    bool? editingIsTask,
    Entry? contextMenuEntry,
    String? splitNotification,
    String? undoBatchId,
    String? undoOriginalText,
    bool clearLastError = false,
    bool clearFilter = false,
    bool clearEditingEntry = false,
    bool clearEditingIsTask = false,
    bool clearContextMenuEntry = false,
    bool clearSplitNotification = false,
    bool clearUndoInfo = false,
  }) {
    return EntryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      lastErrorMessage: clearLastError ? null : (lastErrorMessage ?? this.lastErrorMessage),
      filterCategory: clearFilter ? null : (filterCategory ?? this.filterCategory),
      displayListItems: displayListItems ?? this.displayListItems,
      recentCategories: recentCategories ?? this.recentCategories,
      editingEntry: clearEditingEntry ? null : (editingEntry ?? this.editingEntry),
      isEditingMode: isEditingMode ?? this.isEditingMode,
      editingIsTask: clearEditingIsTask ? null : (editingIsTask ?? this.editingIsTask),
      contextMenuEntry: clearContextMenuEntry ? null : (contextMenuEntry ?? this.contextMenuEntry),
      splitNotification: clearSplitNotification ? null : (splitNotification ?? this.splitNotification),
      undoBatchId: clearUndoInfo ? null : (undoBatchId ?? this.undoBatchId),
      undoOriginalText: clearUndoInfo ? null : (undoOriginalText ?? this.undoOriginalText),
    );
  }
}
