import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// Utility class to manage colors for categories
class CategoryColors {
  static const String _prefs_key = 'category_colors_v1';

  // Predefined set of more muted, text-friendly colors for categories
  // These colors are specifically chosen to work well as backgrounds with text
  static final List<Color> _predefinedColors = [
    const Color(0xFF90CAF9), // Light Blue - muted
    const Color(0xFFEF9A9A), // Light Red - muted
    const Color(0xFFA5D6A7), // Light Green - muted
    const Color(0xFFCE93D8), // Light Purple - muted
    const Color(0xFFFFCC80), // Light Orange - muted
    const Color(0xFF80DEEA), // Light Teal - muted
    const Color(0xFFF48FB1), // Light Pink - muted
    const Color(0xFF9FA8DA), // Light Indigo - muted
    const Color(0xFFFFE082), // Light Amber - muted
    const Color(0xFF80CBC4), // Light Cyan - muted
    const Color(0xFFFFAB91), // Light Deep Orange - muted
    const Color(0xFFE6EE9C), // Light Lime - muted
    const Color(0xFFB39DDB), // Light Deep Purple - muted
    const Color(0xFF81D4FA), // Lighter Blue - muted
    const Color(0xFFBCAAA4), // Light Brown - muted
    const Color(0xFFC5E1A5), // Lighter Green - muted
  ];

  // Map to store category -> color mappings
  static Map<String, Color> _categoryColors = {};
  static final Random _random = Random();

  /// Initialize the color manager by loading saved colors from preferences
  static Future<void> initialize() async {
    await _loadCategoryColors();
  }

  /// Get the color for a specific category
  /// If the category doesn't have a color assigned, it will automatically
  /// assign and save a random color from the predefined set
  static Color getColorForCategory(String category) {
    // If we don't have a color for this category yet, assign one
    if (!_categoryColors.containsKey(category)) {
      _assignColorToCategory(category);
    }
    return _categoryColors[category]!;
  }

  /// Get a darker version of the category color for text
  /// This ensures better contrast for text displayed with the color
  static Color getTextColorForCategory(String category) {
    Color baseColor = getColorForCategory(category);
    // Create a darker version of the color for better text contrast
    HSLColor hslColor = HSLColor.fromColor(baseColor);
    return hslColor
        .withLightness((hslColor.lightness - 0.3).clamp(0.0, 1.0))
        .toColor();
  }

  /// Assign a random color to a category
  static void _assignColorToCategory(String category) {
    // Choose a color that's not already heavily used
    final unusedOrLeastUsedColors = _getLeastUsedColors();
    final color =
        unusedOrLeastUsedColors[_random.nextInt(
          unusedOrLeastUsedColors.length,
        )];

    // Assign and save
    _categoryColors[category] = color;
    _saveCategoryColors();

    AppLogger.info('Assigned color to category "$category"');
  }

  /// Find colors that are used the least among current categories
  static List<Color> _getLeastUsedColors() {
    if (_categoryColors.isEmpty) {
      return List.from(_predefinedColors);
    }

    // Count how many times each predefined color is used
    Map<Color, int> colorUsageCounts = {};
    for (var color in _predefinedColors) {
      colorUsageCounts[color] = 0;
    }

    // Count current usage
    for (var color in _categoryColors.values) {
      if (colorUsageCounts.containsKey(color)) {
        colorUsageCounts[color] = colorUsageCounts[color]! + 1;
      }
    }

    // Find the minimum usage count
    int minUsage = colorUsageCounts.values.reduce(min);

    // Return colors with the minimum usage
    return colorUsageCounts.entries
        .where((entry) => entry.value == minUsage)
        .map((entry) => entry.key)
        .toList();
  }

  /// Manually set a color for a category (for future user customization)
  static Future<void> setColorForCategory(String category, Color color) async {
    _categoryColors[category] = color;
    await _saveCategoryColors();
  }

  /// Load saved category colors from SharedPreferences
  static Future<void> _loadCategoryColors() async {
    Map<String, Color> loadedColors = {}; // Load into a temporary map
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedColors = prefs.getString(_prefs_key);

      if (savedColors != null) {
        try {
          final Map<String, dynamic> decodedMap = jsonDecode(savedColors);

          for (var entry in decodedMap.entries) {
            try {
              // Attempt to parse each entry individually
              final color = _colorFromHex(entry.value as String);
              loadedColors[entry.key] = color;
            } catch (e) {
              // Log error for the specific entry but continue with others
              AppLogger.warning(
                'Error parsing color for category "${entry.key}" (value: ${entry.value}). Skipping.',
                error: e,
              );
            }
          }
          AppLogger.info(
            'Successfully loaded ${loadedColors.length} category colors from preferences.',
          );
        } catch (e) {
          // Error decoding the main JSON string
          AppLogger.error('Error decoding category colors JSON', error: e);
          // Keep whatever was loaded successfully before the JSON error, or empty if JSON was invalid from start
        }
      } else {
        AppLogger.info('No saved category colors found in preferences');
      }
    } catch (e) {
      // Catch errors related to SharedPreferences access itself
      AppLogger.error('Error accessing SharedPreferences for category colors', error: e);
    }
    // Assign the successfully loaded colors (or empty map) to the static variable
    _categoryColors = loadedColors;
  }

  /// Save category colors to SharedPreferences
  static Future<void> _saveCategoryColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert colors to hex strings for storage
      final Map<String, String> colorHexMap = Map.fromEntries(
        _categoryColors.entries.map(
          (entry) => MapEntry(entry.key, _colorToHex(entry.value)),
        ),
      );

      await prefs.setString(_prefs_key, jsonEncode(colorHexMap));
    } catch (e) {
      AppLogger.error('Error saving category colors', error: e);
    }
  }

  /// Convert a hex string to a Color
  static Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceAll('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convert a Color to a hex string
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
