import 'package:flutter/material.dart';
import '../entry/entry.dart';

// CP: Updated approach to handle GlobalKeys with filter context to prevent duplicates
final Map<String, GlobalKey> _entryCardKeys = <String, GlobalKey>{};

// CP: Function to get or create a GlobalKey for an entry card with filter context
GlobalKey entryCardKey(Entry entry, {String? filterContext}) {
  // CP: Include filter context in key to prevent duplicates when filtering
  final filterSuffix = filterContext != null ? '_filter_$filterContext' : '_all';
  final keyString = 'entryCard_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}$filterSuffix';
  return _entryCardKeys.putIfAbsent(keyString, () => GlobalKey());
}

// CP: Function to cleanup old keys when they're no longer needed (optional, for memory management)
void cleanupEntryCardKeys() {
  // CP: Remove keys that might be orphaned - this can be called periodically
  _entryCardKeys.removeWhere((key, globalKey) {
    return globalKey.currentContext == null;
  });
}

// Keys for widgets within the EntriesList item
// Using unique strings based on entry data to ensure key uniqueness per item
ValueKey<String> entryCategoryChipKey(Entry entry) =>
    ValueKey('entryCategoryChip_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}');
ValueKey<String> entryActionsWidgetKey(Entry entry) =>
    ValueKey('entryActionsWidget_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}');
ValueKey<String> entryEditIconKey(Entry entry) =>
    ValueKey('entryEditIcon_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}');
ValueKey<String> entryDeleteIconKey(Entry entry) =>
    ValueKey('entryDeleteIcon_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}');

// Keys for EditEntryDialog
const Key editEntryDialog = ValueKey('editEntryDialog');
const Key editEntryDialogTextField = ValueKey('editEntryDialogTextField');
const Key editEntryDialogCategoryDropdown = ValueKey('editEntryDialogCategoryDropdown');
const Key editEntryDialogSaveButton = ValueKey('editEntryDialogSaveButton'); // For "Update" or "Save"
const Key editEntryDialogCancelButton = ValueKey('editEntryDialogCancelButton'); // For "Cancel"

// General Dialog Action Keys (can be used if specific ones aren't needed or for other dialogs)
const Key dialogSaveButton = ValueKey('dialogSaveButton');
const Key dialogCancelButton = ValueKey('dialogCancelButton');
const Key dialogDeleteButton = ValueKey('dialogDeleteButton');
const Key dialogCloseButton = ValueKey('dialogCloseButton');

// Keys for InputArea (example, can be expanded)
const Key inputTextField = ValueKey('inputTextField');
const Key sendButton = ValueKey('sendButton');
const Key micButton = ValueKey('micButton');
const Key stopRecordingButtonKey = ValueKey('stopRecordingButton');

// Keys for other dialogs (example, can be expanded)
const Key changeCategoryDialog = ValueKey('changeCategoryDialog');
const Key manageCategoriesDialog = ValueKey('manageCategoriesDialog');
const Key helpDialog = ValueKey('helpDialog');
const Key whatsNewDialog = ValueKey('whatsNewDialog');

// Keys for AppBar actions (example, can be expanded)
const Key helpButton = ValueKey('helpButton');
const Key manageCategoriesButton = ValueKey('manageCategoriesButton');

// Keys for Chat interface
const Key chatToggleButton = ValueKey('chatToggleButton');
const Key chatBottomSheet = ValueKey('chatBottomSheet');
const Key chatCloseButton = ValueKey('chatCloseButton');
const Key chatWelcomeMessage = ValueKey('chatWelcomeMessage');
const Key chatThinkingIndicator = ValueKey('chatThinkingIndicator');
const Key chatMessagesList = ValueKey('chatMessagesList');

// CP: Keys for Checklist functionality
ValueKey<String> entryCheckboxKey(Entry entry) =>
    ValueKey('entryCheckbox_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}');

// CP: Keys for Category Management with checklist
const Key addCategoryDialog = ValueKey('addCategoryDialog');
const Key addCategoryNameField = ValueKey('addCategoryNameField');
const Key addCategoryDescriptionField = ValueKey('addCategoryDescriptionField');
const Key addCategoryChecklistToggle = ValueKey('addCategoryChecklistToggle');
const Key addCategoryAddButton = ValueKey('addCategoryAddButton');
const Key addCategoryCancelButton = ValueKey('addCategoryCancelButton');

// CP: Keys for Edit Category Dialog with checklist
const Key editCategoryChecklistToggle = ValueKey('editCategoryChecklistToggle');

// CP: Keys for Category Card indicators
ValueKey<String> categoryChecklistIconKey(String categoryName) =>
    ValueKey('categoryChecklistIcon_$categoryName');

// CP: Keys for Manage Categories Dialog
const Key manageCategoriesDialogDoneButton = ValueKey('manageCategoriesDialogDoneButton');
const Key manageCategoriesDialogAddButton = ValueKey('manageCategoriesDialogAddButton');

// CP: Keys for Edit Category Dialog
const Key editCategoryDialog = ValueKey('editCategoryDialog');
const Key editCategoryNameField = ValueKey('editCategoryNameField');
const Key editCategoryDescriptionField = ValueKey('editCategoryDescriptionField');
const Key editCategorySaveButton = ValueKey('editCategorySaveButton');
const Key editCategoryCancelButton = ValueKey('editCategoryCancelButton');

// CP: Keys for Category List Items in Management Dialog
ValueKey<String> categoryListItemKey(String categoryName) =>
    ValueKey('categoryListItem_$categoryName');

// CP: Keys for generic dialog buttons (fallback)
const Key dialogSaveActionButton = ValueKey('dialogSaveActionButton');
const Key dialogCancelActionButton = ValueKey('dialogCancelActionButton');
const Key dialogDoneActionButton = ValueKey('dialogDoneActionButton');
