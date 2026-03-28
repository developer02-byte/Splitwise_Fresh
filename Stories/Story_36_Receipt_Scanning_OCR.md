# Story 18: Receipt Scanning (OCR) - Detailed Execution Plan

## [DEFERRED v1.5]

---

## 🎯 1. Core Objective & Philosophy
Eliminate ALL manual data entry from expense creation. A user should be able to point their camera at a receipt and have the total amount auto-filled within 2 seconds. All OCR processing happens ON DEVICE via Google ML Kit — no server-side processing, no API calls for text recognition. This is the most powerful UX differentiator from a basic expense tracker.

---

## 👥 2. Target Persona & Motivation
- **The Power User:** Just paid a $347.82 restaurant bill. Doesn't want to type anything. Wants to point phone at receipt, tap "Scan", confirm the number, and split. Done in under 10 seconds.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. Scanning Flow (Flutter — On-Device OCR)
1. **Trigger:** Inside the Add Expense modal, user taps a small camera icon button (`Scan Receipt`) next to the Amount field.
2. **Camera Opens:** The `image_picker` package opens the native camera view (or gallery picker). User positions the receipt and taps capture.
3. **Image Compression:** The captured image is immediately compressed to WebP format, enforcing a max file size of 5MB.
4. **On-Device OCR Processing:** The `google_mlkit_text_recognition` package processes the image entirely on the device. No network call required.
5. **Regex Parsing (Dart):** The recognized text blocks are parsed with a targeted Regex pattern to find the total amount:
   ```dart
   final regex = RegExp(
     r'(TOTAL|GRAND TOTAL|AMOUNT DUE)[\s:]*[\$£€¥]?(\d+[.,]\d{2})',
     caseSensitive: false,
   );
   ```
6. **Candidate Selection:** If multiple matches are found, the largest number is selected (the grand total is always the biggest line on a receipt).
7. **Confidence Scoring:** A confidence score is calculated based on match quality:
   - Exact match on "TOTAL" keyword + clean number = 0.9+
   - Partial keyword match or messy formatting = 0.5–0.8
   - No keyword match, number only = below 0.5
8. **Fallback:** If confidence < 0.5, the UI shows: "Could not read receipt. Enter amount manually." The amount field remains blank for manual entry.
9. **UI Auto-fill:** On success, the Amount field snaps to the detected value (e.g., `$347.82`) and a subtle green confirmation banner appears: "Amount detected from receipt."
10. **User Confirmation:** User reviews the pre-filled amount. Taps "Confirm" or manually corrects.

### B. OCR Pipeline (Dart Implementation)
```dart
Future<OcrResult> scanReceipt(XFile imageFile) async {
  // 1. Load image for ML Kit
  final inputImage = InputImage.fromFilePath(imageFile.path);

  // 2. Run ML Kit text recognition locally
  final textRecognizer = TextRecognizer();
  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
  await textRecognizer.close();

  // 3. Parse text blocks with Regex for total amount
  final regex = RegExp(
    r'(TOTAL|GRAND TOTAL|AMOUNT DUE)[\s:]*[\$£€¥]?(\d+[.,]\d{2})',
    caseSensitive: false,
  );

  double? bestAmount;
  double confidence = 0.0;

  for (final block in recognizedText.blocks) {
    for (final line in block.lines) {
      final match = regex.firstMatch(line.text);
      if (match != null) {
        final amount = double.tryParse(match.group(2)!.replaceAll(',', '.'));
        if (amount != null && (bestAmount == null || amount > bestAmount)) {
          bestAmount = amount;
          confidence = _calculateConfidence(match, line.confidence);
        }
      }
    }
  }

  // 4. If multiple candidates, largest number was already picked above
  // 5. Return confidence score based on match quality
  return OcrResult(
    detectedTotal: bestAmount,
    confidence: confidence,
    rawText: recognizedText.text,
  );
}
```

### C. Receipt Image Storage
1. **On Expense Save:** After the expense is saved, the compressed WebP image is uploaded to file storage (see Story 28 — File Storage).
2. **Database Record:** The returned URL is stored in the `expenses.receipt_image_url` column.
3. **Viewing:** Any group member can tap the receipt thumbnail on the Expense Detail screen to view a full-screen pinch-to-zoom image viewer.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications

### `ScanReceiptButton`
- Icon button (camera icon) adjacent to the Amount input field.
- On tap, shows a brief ripple animation before opening the `image_picker` dialog (camera or gallery).
- Disabled state while OCR is processing.

### `OCRProcessingOverlay`
- A translucent dark overlay with a scanning-animation (corner brackets) and "Scanning..." text.
- Appears immediately after image capture while ML Kit processes.
- Disappears once OCR result is available (typically < 2 seconds on-device).

### `ReceiptThumbnail`
- A small `80x60px` image preview with an expand icon overlay.
- Tapping it opens a full-screen pinch-to-zoom viewer (`InteractiveViewer` widget in Flutter).
- Displayed on both the Add Expense form (after scan) and the Expense Detail screen.

### `AutoFillConfirmBanner`
- A thin green banner below the amount field: "Amount auto-detected: $347.82".
- Dismissible with a close icon.
- If confidence is between 0.5–0.7, banner is yellow with: "Amount may be inaccurate — please verify."

---

## 🚀 5. Technical Architecture & Database

### Flutter Packages Required
| Package | Purpose |
| --- | --- |
| `image_picker` | Camera/gallery access for receipt capture |
| `google_mlkit_text_recognition` | On-device OCR text extraction |
| `image` (dart package) | Image compression and WebP conversion |

### Backend Endpoints
No dedicated OCR endpoint needed — all processing is on-device.

#### Receipt Upload (part of expense save flow)
- **Endpoint:** `POST /api/expenses` (existing) — accepts optional `receipt_image` in multipart body.
- **Controller Logic:**
  1. Validate file type (WebP/JPEG/PNG only) and max size 5MB.
  2. Upload compressed image to file storage (Story 28).
  3. Store returned URL in `expenses.receipt_image_url`.
- **Response:** Standard expense response with `receipt_image_url` field populated.

### Database (Prisma Schema Addition)
```prisma
model Expense {
  // ... existing fields
  receipt_image_url String? @db.VarChar(500)
}
```

### Prisma Migration
```bash
npx prisma migrate dev --name add_receipt_image_url
```

---

## 🧨 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Details |
| --- | --- | --- |
| **Blurry or dark receipt photo** | On-device OCR confidence score < 0.5. | UI shows toast: "Could not read receipt. Enter amount manually." Amount field remains blank. |
| **Multiple totals on receipt** | Subtotal $30, Tax $3, Total $33. | Regex picks the HIGHEST value (`$33`) — the grand total is always the biggest number on a receipt. |
| **Receipt in foreign language** | Japanese receipt with symbols. | ML Kit supports multilingual on-device OCR. Regex handles `$`, `£`, `€`, `¥` currency symbols. |
| **Upload a non-receipt image** | User accidentally uploads a selfie. | OCR finds no matches for total patterns. Returns null total with message: "No receipt total detected." |
| **Image exceeds 5MB after compression** | Large high-res photo. | Compression is re-run at lower quality. If still over 5MB, user is prompted to retake at lower resolution. |
| **Web platform (Flutter Web)** | ML Kit not available on web. | Feature is disabled on Flutter Web. Scan button is hidden. Receipt can still be manually attached as an image. |
| **No camera permission** | User denied camera access. | Gallery picker is offered as fallback. If both denied, feature is unavailable with a clear permission prompt. |

---

## 📝 7. Final QA Acceptance Criteria

- [ ] Scanning a clear English receipt with "TOTAL $347.82" auto-fills the amount field correctly within 2 seconds.
- [ ] OCR processing happens entirely on-device — no network calls made during text recognition (verified via network inspector).
- [ ] Blurry or low-confidence scans (confidence < 0.5) fall back gracefully to manual entry without crashing.
- [ ] Receipt image is compressed to WebP before upload, max 5MB enforced.
- [ ] Receipt image is permanently attached to the expense and viewable by all group members.
- [ ] Full-screen pinch-to-zoom viewer works correctly for receipt images.
- [ ] Maximum receipt image upload size is enforced at 5MB on both frontend and backend.
- [ ] Feature is gracefully hidden/disabled on Flutter Web where ML Kit is unavailable.
