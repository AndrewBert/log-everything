import 'package:flutter/material.dart';
import '../entry/entry.dart';

// CP: Global keys map for entry cards to access their render objects
final Map<String, GlobalKey> _entryCardKeys = <String, GlobalKey>{};

// CP: Function to get or create a GlobalKey for an entry card
GlobalKey entryCardKey(Entry entry) {
  final keyString =
      'entryCard_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}';
  return _entryCardKeys.putIfAbsent(keyString, () => GlobalKey());
}

// Keys for widgets within the EntriesList item
// Using unique strings based on entry data to ensure key uniqueness per item
ValueKey<String> entryCategoryChipKey(Entry entry) => ValueKey(
  'entryCategoryChip_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}',
);
ValueKey<String> entryActionsWidgetKey(Entry entry) => ValueKey(
  'entryActionsWidget_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}',
);
ValueKey<String> entryEditIconKey(Entry entry) => ValueKey(
  'entryEditIcon_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}',
);
ValueKey<String> entryDeleteIconKey(Entry entry) => ValueKey(
  'entryDeleteIcon_${entry.timestamp.toIso8601String()}_${entry.text.hashCode}',
);

// Keys for EditEntryDialog
const Key editEntryDialog = ValueKey('editEntryDialog');
const Key editEntryDialogTextField = ValueKey('editEntryDialogTextField');
const Key editEntryDialogCategoryDropdown = ValueKey(
  'editEntryDialogCategoryDropdown',
);
const Key editEntryDialogSaveButton = ValueKey(
  'editEntryDialogSaveButton',
); // For "Update" or "Save"
const Key editEntryDialogCancelButton = ValueKey(
  'editEntryDialogCancelButton',
); // For "Cancel"

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
