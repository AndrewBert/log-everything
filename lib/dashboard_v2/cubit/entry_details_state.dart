part of 'entry_details_cubit.dart';

enum SaveStatus { idle, saving, saved }

class EntryDetailsState extends Equatable {
  final Entry? entry;
  final bool isEditing;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final Insight? primaryInsight;
  final bool isRegeneratingInsight;
  final String? editedText;
  final SaveStatus saveStatus;
  final String? originalEntryText;

  const EntryDetailsState({
    this.entry,
    this.isEditing = false,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.primaryInsight,
    this.isRegeneratingInsight = false,
    this.editedText,
    this.saveStatus = SaveStatus.idle,
    this.originalEntryText,
  });

  EntryDetailsState copyWith({
    Entry? entry,
    bool? isEditing,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    Insight? primaryInsight,
    bool clearPrimaryInsight = false,
    bool? isRegeneratingInsight,
    String? editedText,
    bool clearEditedText = false,
    SaveStatus? saveStatus,
    String? originalEntryText,
    bool clearOriginalEntryText = false,
  }) {
    return EntryDetailsState(
      entry: entry ?? this.entry,
      isEditing: isEditing ?? this.isEditing,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      primaryInsight: clearPrimaryInsight ? null : (primaryInsight ?? this.primaryInsight),
      isRegeneratingInsight: isRegeneratingInsight ?? this.isRegeneratingInsight,
      editedText: clearEditedText ? null : (editedText ?? this.editedText),
      saveStatus: saveStatus ?? this.saveStatus,
      originalEntryText: clearOriginalEntryText ? null : (originalEntryText ?? this.originalEntryText),
    );
  }

  @override
  List<Object?> get props => [
        entry,
        isEditing,
        isLoading,
        isSaving,
        errorMessage,
        primaryInsight,
        isRegeneratingInsight,
        editedText,
        saveStatus,
        originalEntryText,
      ];
}