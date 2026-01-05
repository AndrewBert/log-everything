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
  // CP: Entry that was categorized as Misc and needs user categorization
  final Entry? entryPendingCategorization;

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
    this.entryPendingCategorization,
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
    entryPendingCategorization,
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
    Entry? entryPendingCategorization,
    bool clearLastError = false,
    bool clearFilter = false,
    bool clearEditingEntry = false,
    bool clearEditingIsTask = false,
    bool clearContextMenuEntry = false,
    bool clearSplitNotification = false,
    bool clearEntryPendingCategorization = false,
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
      entryPendingCategorization: clearEntryPendingCategorization
          ? null
          : (entryPendingCategorization ?? this.entryPendingCategorization),
    );
  }
}
