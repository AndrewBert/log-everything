# Image Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add image capture with AI-powered categorization and description to entries.

**Architecture:** Extend Entry model with image fields, create ImageStorageService for local persistence, extend AiService with GPT-4.1 vision API, modify UI to support image picker and display.

**Tech Stack:** Flutter, image_picker, path_provider, GPT-4.1 vision API

---

## Task 1: Add Image Fields to Entry Model

**Files:**
- Modify: `lib/entry/entry.dart`

**Step 1: Add image fields to Entry class**

Add three new nullable fields after existing fields:

```dart
final String? imagePath;        // Relative path to image in app storage
final String? imageTitle;       // Brief 2-4 word AI title for cards
final String? imageDescription; // 1-2 sentence AI description
```

**Step 2: Update constructor**

Add optional parameters:

```dart
this.imagePath,
this.imageTitle,
this.imageDescription,
```

**Step 3: Update fromJson factory**

Add parsing for new fields:

```dart
imagePath: json['imagePath'] as String?,
imageTitle: json['imageTitle'] as String?,
imageDescription: json['imageDescription'] as String?,
```

**Step 4: Update toJson method**

Add serialization:

```dart
'imagePath': imagePath,
'imageTitle': imageTitle,
'imageDescription': imageDescription,
```

**Step 5: Update copyWith method**

Add parameters with clear flags:

```dart
String? imagePath,
bool clearImagePath = false,
String? imageTitle,
bool clearImageTitle = false,
String? imageDescription,
bool clearImageDescription = false,
```

And in the return:

```dart
imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
imageTitle: clearImageTitle ? null : (imageTitle ?? this.imageTitle),
imageDescription: clearImageDescription ? null : (imageDescription ?? this.imageDescription),
```

**Step 6: Update Equatable props**

Add new fields to props list.

**Step 7: Commit**

```bash
git add lib/entry/entry.dart
git commit -m "feat: add image fields to Entry model"
```

---

## Task 2: Create ImageStorageService

**Files:**
- Create: `lib/services/image_storage_service.dart`

**Step 1: Create service interface and implementation**

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import '../utils/logger.dart';

abstract class ImageStorageService {
  Future<String> saveImage(File imageFile);
  Future<String> saveImageBytes(Uint8List bytes, String extension);
  Future<void> deleteImage(String relativePath);
  Future<File?> getImage(String relativePath);
  Future<String> getFullPath(String relativePath);
  Future<Uint8List?> getImageBytes(String relativePath);
}

class LocalImageStorageService implements ImageStorageService {
  static const String _imagesFolder = 'images';
  static const int _maxDimension = 1920;
  static const int _jpegQuality = 80;

  @override
  Future<String> saveImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();
    return saveImageBytes(bytes, extension);
  }

  @override
  Future<String> saveImageBytes(Uint8List bytes, String extension) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/$_imagesFolder');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Compress image
    final compressed = await _compressImage(bytes);

    // Generate unique filename
    final filename = '${const Uuid().v4()}.jpg';
    final relativePath = '$_imagesFolder/$filename';
    final fullPath = '${appDir.path}/$relativePath';

    // Save file
    final file = File(fullPath);
    await file.writeAsBytes(compressed);

    AppLogger.info('ImageStorageService: Saved image to $relativePath');
    return relativePath;
  }

  @override
  Future<void> deleteImage(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/$relativePath';
    final file = File(fullPath);

    if (await file.exists()) {
      await file.delete();
      AppLogger.info('ImageStorageService: Deleted image at $relativePath');
    }
  }

  @override
  Future<File?> getImage(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/$relativePath';
    final file = File(fullPath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }

  @override
  Future<String> getFullPath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  @override
  Future<Uint8List?> getImageBytes(String relativePath) async {
    final file = await getImage(relativePath);
    if (file != null) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if too large
    img.Image resized = image;
    if (image.width > _maxDimension || image.height > _maxDimension) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: _maxDimension);
      } else {
        resized = img.copyResize(image, height: _maxDimension);
      }
    }

    // Encode as JPEG with compression
    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/image_storage_service.dart
git commit -m "feat: add ImageStorageService for local image persistence"
```

---

## Task 3: Register ImageStorageService in DI

**Files:**
- Modify: `lib/locator.dart`

**Step 1: Add import**

```dart
import 'package:myapp/services/image_storage_service.dart';
```

**Step 2: Register service**

Add after other service registrations:

```dart
getIt.registerLazySingleton<ImageStorageService>(() => LocalImageStorageService());
```

**Step 3: Commit**

```bash
git add lib/locator.dart
git commit -m "feat: register ImageStorageService in DI container"
```

---

## Task 4: Add Vision API to AiService

**Files:**
- Modify: `lib/services/ai_service.dart`

**Step 1: Add new typedef for image analysis result**

After existing typedefs:

```dart
typedef ImageAnalysisResult = ({
  String category,
  bool isTask,
  String imageTitle,
  String imageDescription,
  String insight,
});
```

**Step 2: Add method to AiService interface**

```dart
/// Analyzes an image and returns categorization and description.
Future<ImageAnalysisResult> analyzeImage({
  required Uint8List imageBytes,
  required List<Category> categories,
  String? userNote,
});
```

**Step 3: Implement in OpenAiService**

Add implementation after generateSimpleInsight:

```dart
static const gpt41 = 'gpt-4.1';

@override
Future<ImageAnalysisResult> analyzeImage({
  required Uint8List imageBytes,
  required List<Category> categories,
  String? userNote,
}) async {
  if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
    throw AiServiceException('OpenAI API Key not found.');
  }
  if (categories.isEmpty) {
    throw AiServiceException('No categories provided for classification.');
  }

  AppLogger.info("Calling OpenAI Vision API (gpt-4.1) to analyze image");

  final categoryNames = categories.map((cat) => cat.name).toList();
  final categoriesListString = categories
      .map((cat) => cat.description.trim().isNotEmpty
          ? '- ${cat.name}: ${cat.description}'
          : '- ${cat.name}')
      .join('\n');

  final base64Image = base64Encode(imageBytes);
  final userNoteContext = userNote != null && userNote.isNotEmpty
      ? "\n\nUser's note about this image: \"$userNote\""
      : "";

  final prompt = '''Analyze this image for a personal logging app.$userNoteContext

Available categories:
$categoriesListString

Return a JSON object with:
{
  "category": "best matching category from the list above",
  "isTask": true/false (is this something actionable like a receipt to file, a whiteboard todo, etc.),
  "imageTitle": "2-4 word title for the image",
  "imageDescription": "1-2 sentence factual description of what's in the image",
  "insight": "brief interpretive reflection or helpful observation"
}

Be concise. Use ONLY category names from the provided list.''';

  final requestBody = {
    'model': gpt41,
    'input': [
      {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': prompt},
          {
            'type': 'input_image',
            'image_url': 'data:image/jpeg;base64,$base64Image',
          },
        ],
      },
    ],
    'text': {
      'format': {'type': 'json_object'},
    },
    'metadata': {
      'request_type': 'image_analysis',
      'app_name': 'log-everything',
      'timestamp': DateTime.now().toIso8601String(),
      'model_used': gpt41,
    },
  };

  try {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);

      if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
        throw AiServiceException(
          'OpenAI request failed. Status: ${responseBody['status']}. Error: ${responseBody['error']}',
        );
      }

      // Parse response
      Map<String, dynamic>? messageOutput;
      for (var output in responseBody['output']) {
        if (output['type'] == 'message' && output['content'] != null) {
          messageOutput = output;
          break;
        }
      }

      if (messageOutput != null &&
          messageOutput['content'] is List &&
          messageOutput['content'].isNotEmpty) {
        for (final item in messageOutput['content']) {
          if (item['type'] == 'output_text' && item['text'] != null) {
            final json = jsonDecode(item['text']);

            final category = json['category'] as String? ?? 'Misc';
            final validCategory = categoryNames.contains(category) ? category : 'Misc';

            return (
              category: validCategory,
              isTask: json['isTask'] as bool? ?? false,
              imageTitle: json['imageTitle'] as String? ?? 'Image',
              imageDescription: json['imageDescription'] as String? ?? '',
              insight: json['insight'] as String? ?? '',
            );
          }
        }
      }

      throw AiServiceException('Unexpected response format from OpenAI Vision API');
    } else {
      throw AiServiceException('OpenAI Vision API HTTP error (Code: ${response.statusCode})');
    }
  } catch (e) {
    if (e is AiServiceException) rethrow;
    throw AiServiceException('Image analysis failed: ${e.toString()}', underlyingError: e);
  }
}
```

**Step 4: Add import for dart:typed_data if not present**

```dart
import 'dart:typed_data';
```

**Step 5: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "feat: add Vision API integration to AiService"
```

---

## Task 5: Add Image Entry Support to EntryRepository

**Files:**
- Modify: `lib/entry/repository/entry_repository.dart`

**Step 1: Add ImageStorageService dependency**

Import and add to constructor:

```dart
import '../../services/image_storage_service.dart';
```

Add field:
```dart
final ImageStorageService _imageStorageService;
```

Update constructor:
```dart
EntryRepository({
  required EntryPersistenceService persistenceService,
  required AiService aiService,
  required VectorStoreService vectorStoreService,
  required TimerFactory timerFactory,
  required ImageStorageService imageStorageService,
}) : _persistenceService = persistenceService,
     _aiService = aiService,
     _vectorStoreService = vectorStoreService,
     _timerFactory = timerFactory,
     _imageStorageService = imageStorageService;
```

**Step 2: Add addImageEntry method**

```dart
Future<({List<Entry> entries, Entry? addedEntry})> addImageEntry({
  required Uint8List imageBytes,
  String? userNote,
}) async {
  final DateTime processingTimestamp = DateTime.now();

  try {
    // Save image to local storage
    final imagePath = await _imageStorageService.saveImageBytes(imageBytes, 'jpg');

    // Analyze image with AI
    final analysis = await _aiService.analyzeImage(
      imageBytes: imageBytes,
      categories: _categories,
      userNote: userNote,
    );

    // Create entry with image fields
    final newEntry = Entry(
      text: userNote ?? '',
      timestamp: processingTimestamp,
      category: analysis.category,
      isNew: true,
      isTask: analysis.isTask,
      imagePath: imagePath,
      imageTitle: analysis.imageTitle,
      imageDescription: analysis.imageDescription,
      simpleInsight: SimpleInsight(
        content: analysis.insight,
        generatedAt: DateTime.now(),
      ),
    );

    _entries.insert(0, newEntry);
    await _saveEntries();

    _triggerVectorStoreSyncForMonth(processingTimestamp).catchError((e, stackTrace) {
      AppLogger.error("Repository: Background vector store sync failed for addImageEntry",
        error: e, stackTrace: stackTrace);
    });

    return (entries: currentEntries, addedEntry: newEntry);
  } catch (e) {
    AppLogger.error("Repository: Error adding image entry", error: e);

    // Fallback: save with minimal data
    final imagePath = await _imageStorageService.saveImageBytes(imageBytes, 'jpg');
    final fallbackEntry = Entry(
      text: userNote ?? '',
      timestamp: processingTimestamp,
      category: 'Misc',
      isNew: true,
      imagePath: imagePath,
      imageTitle: 'Image',
    );

    _entries.insert(0, fallbackEntry);
    await _saveEntries();

    return (entries: currentEntries, addedEntry: fallbackEntry);
  }
}
```

**Step 3: Update deleteEntry to clean up images**

In deleteEntry method, before removing from _entries:

```dart
// Delete associated image if exists
final entryToRemove = _entries.firstWhere(
  (entry) => entry.timestamp == entryToDelete.timestamp && entry.text == entryToDelete.text,
  orElse: () => entryToDelete,
);
if (entryToRemove.imagePath != null) {
  await _imageStorageService.deleteImage(entryToRemove.imagePath!);
}
```

**Step 4: Add import for dart:typed_data**

```dart
import 'dart:typed_data';
```

**Step 5: Commit**

```bash
git add lib/entry/repository/entry_repository.dart
git commit -m "feat: add image entry support to EntryRepository"
```

---

## Task 6: Update DI Registration for EntryRepository

**Files:**
- Modify: `lib/locator.dart`

**Step 1: Update EntryRepository registration**

```dart
getIt.registerLazySingleton(
  () => EntryRepository(
    persistenceService: getIt<EntryPersistenceService>(),
    aiService: getIt<AiService>(),
    vectorStoreService: getIt<VectorStoreService>(),
    timerFactory: getIt<TimerFactory>(),
    imageStorageService: getIt<ImageStorageService>(),
  ),
);
```

**Step 2: Commit**

```bash
git add lib/locator.dart
git commit -m "feat: inject ImageStorageService into EntryRepository"
```

---

## Task 7: Add image_picker and image Packages

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add dependencies**

```yaml
dependencies:
  image_picker: ^1.0.7
  image: ^4.1.7
```

**Step 2: Run pub get**

```bash
flutter pub get
```

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add image_picker and image packages"
```

---

## Task 8: Add Image Button to FloatingInputBar

**Files:**
- Modify: `lib/dashboard_v2/widgets/floating_input_bar.dart`

**Step 1: Add imports**

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
```

**Step 2: Add state variables**

In _FloatingInputBarState:

```dart
File? _selectedImage;
bool _isProcessingImage = false;
final ImagePicker _imagePicker = ImagePicker();
```

**Step 3: Add image picker methods**

```dart
Future<void> _showImageSourceSheet() async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickImage(ImageSource source) async {
  try {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      // Expand input bar to show preview
      _animationController.forward();
      setState(() {
        _isExpanded = true;
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}

void _clearImage() {
  setState(() {
    _selectedImage = null;
  });
  HapticFeedback.lightImpact();
}
```

**Step 4: Update _handleSubmit to handle images**

Modify _handleSubmit:

```dart
Future<void> _handleSubmit() async {
  final text = _textController.text.trim();
  final hasImage = _selectedImage != null;

  if (text.isEmpty && !hasImage) return;
  if (_isSubmitting || _isProcessingImage) return;

  setState(() {
    _isSubmitting = true;
    if (hasImage) _isProcessingImage = true;
  });

  try {
    if (hasImage) {
      final imageBytes = await _selectedImage!.readAsBytes();
      await context.read<DashboardV2Cubit>().handleImageInput(
        imageBytes,
        userNote: text.isNotEmpty ? text : null,
        context: context,
      );
      _clearImage();
    } else {
      await context.read<DashboardV2Cubit>().handleUserInput(text, context);
    }

    _textController.clear();
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();
    // ... rest of reset logic
  } catch (e) {
    // ... error handling
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isProcessingImage = false;
      });
    }
  }
}
```

**Step 5: Add image button to Row**

In the Row children, before the text field:

```dart
// Image picker button (left side)
if (!_hasText && !_isExpanded && _selectedImage == null) ...[
  IconButton(
    onPressed: _showImageSourceSheet,
    icon: Icon(
      Icons.camera_alt_outlined,
      color: theme.colorScheme.onSurfaceVariant,
    ),
    tooltip: 'Add Image',
  ),
],
```

**Step 6: Add image preview above input**

Add above the Row in the Stack, when image is selected:

```dart
if (_selectedImage != null)
  Positioned(
    top: 0,
    left: 8,
    right: 8,
    child: Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: FileImage(_selectedImage!),
          fit: BoxFit.cover,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: IconButton(
          onPressed: _clearImage,
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ),
      ),
    ),
  ),
```

**Step 7: Update hint text when image selected**

```dart
hintText: _selectedImage != null
    ? "Add a note (optional)..."
    : _justTranscribed
        ? "Review transcription..."
        : "What's on your mind?",
```

**Step 8: Commit**

```bash
git add lib/dashboard_v2/widgets/floating_input_bar.dart
git commit -m "feat: add image picker to FloatingInputBar"
```

---

## Task 9: Add handleImageInput to DashboardV2Cubit

**Files:**
- Modify: `lib/dashboard_v2/cubit/dashboard_v2_cubit.dart`

**Step 1: Add import**

```dart
import 'dart:typed_data';
```

**Step 2: Add handleImageInput method**

```dart
Future<void> handleImageInput(
  Uint8List imageBytes, {
  String? userNote,
  required BuildContext context,
}) async {
  try {
    final result = await _entryRepository.addImageEntry(
      imageBytes: imageBytes,
      userNote: userNote,
    );

    if (result.addedEntry != null) {
      // Show success feedback
      _snackbarService.showSuccess('Image added successfully');
    }
  } catch (e) {
    AppLogger.error('Error adding image entry', error: e);
    _snackbarService.showError('Failed to add image');
  }
}
```

**Step 3: Commit**

```bash
git add lib/dashboard_v2/cubit/dashboard_v2_cubit.dart
git commit -m "feat: add handleImageInput to DashboardV2Cubit"
```

---

## Task 10: Create Image Entry Card Widget

**Files:**
- Create: `lib/dashboard_v2/widgets/image_entry_card.dart`

**Step 1: Create widget**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/services/image_storage_service.dart';

class ImageEntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isSelected;

  const ImageEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<String>(
        future: GetIt.instance<ImageStorageService>().getFullPath(entry.imagePath!),
        builder: (context, snapshot) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (snapshot.hasData)
                  Image.file(
                    File(snapshot.data!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                else
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // Gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Title overlay
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Text(
                    entry.imageTitle ?? 'Image',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/dashboard_v2/widgets/image_entry_card.dart
git commit -m "feat: create ImageEntryCard widget with gradient overlay"
```

---

## Task 11: Update Entry Display Logic

**Files:**
- Modify: `lib/dashboard_v2/widgets/recent_entries_carousel.dart` (or wherever entries are displayed)

**Step 1: Add import**

```dart
import 'image_entry_card.dart';
```

**Step 2: Use ImageEntryCard for image entries**

In the item builder, check for imagePath:

```dart
if (entry.imagePath != null) {
  return ImageEntryCard(
    entry: entry,
    onTap: () => _navigateToDetails(entry),
    isSelected: isSelected,
  );
} else {
  return NewspaperEntryCard(
    entry: entry,
    onTap: () => _navigateToDetails(entry),
    isSelected: isSelected,
  );
}
```

**Step 3: Commit**

```bash
git add lib/dashboard_v2/widgets/
git commit -m "feat: use ImageEntryCard for entries with images"
```

---

## Task 12: Update Entry Details Page for Images

**Files:**
- Modify: `lib/dashboard_v2/pages/entry_details_page.dart`

**Step 1: Add imports**

```dart
import 'dart:io';
import 'package:myapp/services/image_storage_service.dart';
```

**Step 2: Add image display section in _buildBody**

Before the entry text section, add image display:

```dart
// Image display for image entries
if (entry.imagePath != null)
  FutureBuilder<String>(
    future: GetIt.instance<ImageStorageService>().getFullPath(entry.imagePath!),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
      }
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, snapshot.data!),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      );
    },
  ),

// Image description (AI-generated)
if (entry.imageDescription != null && entry.imageDescription!.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      entry.imageDescription!,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    ),
  ),

// User's note (if exists for image entries)
if (entry.imagePath != null && entry.text.isNotEmpty)
  Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(entry.text, style: theme.textTheme.bodyLarge),
      ],
    ),
  ),
```

**Step 3: Add full screen image viewer**

```dart
void _showFullScreenImage(BuildContext context, String imagePath) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    ),
  );
}
```

**Step 4: Commit**

```bash
git add lib/dashboard_v2/pages/entry_details_page.dart
git commit -m "feat: display images and descriptions on entry details page"
```

---

## Task 13: Update Search to Include Image Fields

**Files:**
- Modify: `lib/search/cubit/search_cubit.dart`

**Step 1: Update _performSearch**

```dart
void _performSearch(String query) {
  final normalizedQuery = query.toLowerCase();
  final allEntries = _entryRepository.currentEntries;

  final results = allEntries.where((entry) {
    // Search text content
    if (entry.text.toLowerCase().contains(normalizedQuery)) return true;

    // Search image title
    if (entry.imageTitle?.toLowerCase().contains(normalizedQuery) ?? false) return true;

    // Search image description
    if (entry.imageDescription?.toLowerCase().contains(normalizedQuery) ?? false) return true;

    return false;
  }).toList();

  emit(state.copyWith(
    results: results,
    isSearching: false,
  ));
}
```

**Step 2: Commit**

```bash
git add lib/search/cubit/search_cubit.dart
git commit -m "feat: search image title and description fields"
```

---

## Task 14: Update Vector Store Sync Format

**Files:**
- Modify: `lib/entry/repository/entry_repository.dart`

**Step 1: Update _triggerVectorStoreSyncForMonth content formatting**

Replace the formatting block:

```dart
formattedContent = entriesForMonth
    .map((entry) {
      final String timestampStr = _formatTimestampForLogEntry(entry.timestamp);

      // Format differently for image entries
      if (entry.imagePath != null) {
        final parts = <String>[];
        if (entry.imageTitle != null) parts.add(entry.imageTitle!);
        if (entry.imageDescription != null) parts.add('Description: ${entry.imageDescription}');
        if (entry.text.isNotEmpty) parts.add('Note: ${entry.text}');

        return "[$timestampStr] (${entry.category}): ${parts.join(' | ')}";
      }

      return "[$timestampStr] (${entry.category}): ${entry.text}";
    })
    .join('\n---\n');
```

**Step 2: Commit**

```bash
git add lib/entry/repository/entry_repository.dart
git commit -m "feat: include image metadata in vector store sync"
```

---

## Task 15: Add iOS Permissions for Camera and Photo Library

**Files:**
- Modify: `ios/Runner/Info.plist`

**Step 1: Add permission descriptions**

Add inside the `<dict>` tag:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture photos for your log entries.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to attach images to your log entries.</string>
```

**Step 2: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "feat: add iOS camera and photo library permissions"
```

---

## Summary

After completing all tasks, the image support feature will include:

1. **Data Model**: Entry supports imagePath, imageTitle, imageDescription
2. **Storage**: LocalImageStorageService saves compressed images to app documents
3. **AI**: GPT-4.1 vision API analyzes images for category, title, description, insight
4. **UI Input**: Camera icon on FloatingInputBar, bottom sheet for source selection
5. **UI Display**: ImageEntryCard with gradient overlay, full details on entry page
6. **Search**: Queries match against image title and description
7. **Vector Store**: Image metadata included for chat queries
