import 'package:flutter/material.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';

class TestData {
  static const testEntryText = 'Test entry 1';
  static final now = DateTime.now();
  static final today = DateTime(now.year, now.month, now.day);
  static final yesterday = today.subtract(const Duration(days: 1));
  static final twoDaysAgo = today.subtract(const Duration(days: 2));

  static final entryToday1 = Entry(
    text: 'Entry today 1',
    timestamp: today.add(const Duration(hours: 14, minutes: 30)),
    category: 'Misc',
  );

  static final entryToday2 = Entry(
    text: 'Entry today 2',
    timestamp: today.add(const Duration(hours: 10, minutes: 15)),
    category: 'Work',
  );

  static final entryYesterday = Entry(
    text: 'Entry yesterday',
    timestamp: yesterday.add(const Duration(hours: 4)),
    category: 'Personal',
  );

  static final entryOlder = Entry(
    text: 'Entry older',
    timestamp: twoDaysAgo.add(const Duration(hours: 9)),
    category: 'Misc',
  );

  static final rawEntriesList = [entryToday1, entryToday2, entryYesterday, entryOlder];

  static final categoriesList = [
    Category(name: 'Misc', description: 'Miscellaneous entries', color: const Color(0xFF9E9E9E)),
    Category(name: 'Work', description: 'Work-related entries', color: const Color(0xFF2196F3)),
    Category(name: 'Personal', description: 'Personal entries', color: const Color(0xFF4CAF50)),
  ];

  // CP: Checklist test data
  static final checklistCategory = Category(
    name: 'TodoList',
    description: 'Tasks and checklist items',
    isChecklist: true,
    color: const Color(0xFFFF9800),
  );

  static final regularCategory = Category(
    name: 'Notes',
    description: 'Regular notes and thoughts',
    isChecklist: false,
    color: const Color(0xFF9C27B0),
  );

  static final checklistEntryIncomplete = Entry(
    text: 'Buy groceries',
    timestamp: today.add(const Duration(hours: 12)),
    category: 'TodoList',
    isCompleted: false,
  );

  static final checklistEntryCompleted = Entry(
    text: 'Finish weekly report',
    timestamp: today.add(const Duration(hours: 11)),
    category: 'TodoList',
    isCompleted: true,
  );

  static final regularEntry = Entry(
    text: 'Meeting notes from today',
    timestamp: today.add(const Duration(hours: 13)),
    category: 'Notes',
    isCompleted: false, // CP: Should be ignored for regular entries
  );

  static final checklistEntriesWithMixed = [
    checklistEntryIncomplete,
    checklistEntryCompleted,
    regularEntry,
  ];

  static final categoriesWithChecklist = [
    ...categoriesList,
    checklistCategory,
    regularCategory,
  ];

  static List<Entry> getExpectedEntriesAfterDelete(Entry entryToDelete) {
    return List<Entry>.from(rawEntriesList)
      ..removeWhere((e) => e.timestamp == entryToDelete.timestamp && e.text == entryToDelete.text);
  }

  static List<Entry> getExpectedEntriesAfterUndo(Entry entryToRestore) {
    return List<Entry>.from(rawEntriesList)
      ..removeWhere((e) => e.timestamp == entryToRestore.timestamp && e.text == entryToRestore.text)
      ..add(entryToRestore);
  }
}
