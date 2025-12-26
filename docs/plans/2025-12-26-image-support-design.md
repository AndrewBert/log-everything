# Image Support for Notes

## Overview

Add image capture and AI analysis to entries. Users can snap photos of receipts, whiteboards, documents, etc. and have them automatically categorized and described by AI. Text is optional when an image is provided.

## Data Model

Add three new fields to `Entry`:

```dart
class Entry extends Equatable {
  // ... existing fields ...
  final String? imagePath;        // Relative path to image in app storage
  final String? imageTitle;       // Brief 2-4 word title for card display
  final String? imageDescription; // 1-2 sentence factual description
}
```

**Validation:** Entry must have either `text` or `imagePath` (or both).

**Text fields for image entries:**
1. `text` - User's note (optional, user-provided)
2. `simpleInsight` - AI interpretation (existing, unchanged position)
3. `imageTitle` - Brief AI-generated title for cards
4. `imageDescription` - AI-generated description of image contents

## Image Storage

New `ImageStorageService` handles image persistence:

- Save to app documents directory under `images/` folder
- UUID-based filenames (e.g., `images/a1b2c3d4.jpg`)
- Store relative paths in Entry (survives app updates)
- Compress images before saving (max 1920px, ~80% JPEG quality)
- Delete images when entries are deleted
- Lazy singleton registration in `locator.dart`

## AI Vision Integration

Extend `AiService` with `categorizeImageEntry(imagePath, optionalText)`:

**Model:** `gpt-4.1` (latest vision-capable model)

**Single API call returns:**
```json
{
  "category": "best matching category",
  "isTask": true/false,
  "imageTitle": "2-4 word title",
  "imageDescription": "1-2 sentence factual description",
  "insight": "brief interpretive reflection"
}
```

**Prompt includes:**
- User's category list with descriptions
- User's note if provided
- Instructions for JSON output format

**Error handling:**
- API failure: Save entry with image but null AI fields
- Show error snackbar, allow retry from details page

## UI: Floating Input Bar

Layout with image button on left:
```
[camera icon] [____text input____] [mic/send]
```

**Image button behavior:**
- Tap shows bottom sheet: "Take Photo" / "Choose from Gallery"
- Uses `image_picker` package
- Selected image shows as thumbnail preview above input bar
- X button on thumbnail to remove before submitting
- Text placeholder changes to "Add a note (optional)..."

**Submission flow:**
- Image + optional text sent to `EntryRepository`
- Repository coordinates saving image and AI categorization
- Entry created with all fields populated

## UI: Entry Cards (Dashboard, Category Pages)

**Image entries display:**
- Image fills card background
- Bottom 20% has gradient fade: transparent → grey/dark
- AI-generated `imageTitle` overlaid at bottom (white text)
- User's note NOT shown on card
- Same style whether user added a note or not

**Text entries:** Unchanged from current design.

## UI: Entry Details Page

**Image entry layout (top to bottom):**
1. Full-width image (tappable for full-screen viewer)
2. AI image description (`imageDescription`)
3. User's note (`text`) if exists
4. AI insight (`simpleInsight`) in existing position

**Full-screen image viewer:**
- Pinch-to-zoom support
- Simple overlay with close button
- Use `photo_view` package or `InteractiveViewer`

## Search

**Local search queries against:**
- `text` (user note)
- `imageTitle`
- `imageDescription`

**Results display:** Same card style as dashboard (image background + title overlay).

## Vector Store Sync

Image entries included in monthly sync files for chat queries:

```
[2025-01-15 10:30] [Receipts] Grocery Receipt
Description: Shopping receipt from Whole Foods showing groceries totaling $87.43
Note: Need to expense this for work trip
```

**Synced fields:** `imageTitle`, `imageDescription`, `text` (if exists), `category`, `timestamp`

## Package Dependencies

| Package | Purpose |
|---------|---------|
| `image_picker` | Camera and gallery access |
| `path_provider` | App documents directory (likely already present) |
| `photo_view` | Full-screen image viewer with zoom (optional) |

## Implementation Order

1. Data model: Add fields to `Entry` with JSON serialization
2. `ImageStorageService`: Create service for local image storage
3. `AiService`: Add vision API integration with `gpt-4.1`
4. `EntryRepository`: Coordinate image saving and AI analysis
5. `FloatingInputBar`: Add image picker button and preview
6. Entry cards: Image background with gradient and title overlay
7. Entry details: Display image, description, note, insight
8. Full-screen viewer: Zoomable image display
9. Search: Include new fields in search queries
10. Vector store: Update sync format for image entries
