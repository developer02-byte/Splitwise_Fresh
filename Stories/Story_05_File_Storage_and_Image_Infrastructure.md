# Story 28: File Storage & Image Infrastructure - Detailed Execution Plan

## 1. Core Objective & Philosophy
Provide a unified, scalable file storage system for all image and file uploads in the app — receipt images, user avatars, group cover photos, and comment attachments. Every file flows through a single, validated pipeline regardless of type. No file touches permanent storage without passing compression, MIME validation, and size checks.

---

## 2. Target Persona & Motivation
- **The Receipt Uploader:** Alice photographs a dinner receipt to attach to a $120 expense. She expects it to upload fast on mobile data and display clearly when Bob checks the details later.
- **The Profile Customizer:** Bob wants a custom avatar and group cover photo. He uploads a 12MB DSLR photo and expects the app to handle it gracefully (compress, crop, store) without making him resize it manually.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Avatar Upload
1. **Trigger:** User navigates to Profile (Story 10) and taps their avatar circle.
2. **Action - Source Selection:** Bottom sheet offers "Take Photo" (camera) or "Choose from Gallery" (image_picker Flutter package).
3. **Client-Side Processing:** Flutter crops to square (1:1 aspect ratio) using `image_cropper` package. Compresses to max 256x256px, quality 80%. If file exceeds 5MB after compression, further reduce quality.
4. **Upload:** `POST /api/files/upload` with `multipart/form-data`. Fields: `file` (binary), `file_type` = `avatar`.
5. **Server Processing:** Fastify receives multipart stream via `@fastify/multipart`. Validates MIME type (image/jpeg, image/png, image/webp only). Converts to WebP using `sharp`. Stores file. Returns `{ file_id, public_url }`.
6. **Link to Record:** Client calls `PATCH /api/users/me` with `{ avatar_file_id: file_id }`. Backend updates user record and marks old avatar for cleanup.
7. **UI Update:** Avatar refreshes immediately. Old avatar's file record is marked as orphaned (will be cleaned up by background job).

### B. Receipt Image Upload
1. **Trigger:** User taps "Attach Receipt" on Add Expense screen (Story 03) or in a comment (Story 21).
2. **Client-Side Processing:** Image compressed to max 2048px width, maintaining aspect ratio. Quality 85%.
3. **Upload:** `POST /api/files/upload` with `file_type` = `receipt`.
4. **Server Processing:** Same validation pipeline. Converts to WebP. Generates a thumbnail (400px width) in addition to full-size image. Stores both.
5. **Access:** Receipt URLs are signed (private). Requesting user must be a member of the associated group. Signed URL expires after 1 hour.

### C. Group Cover Photo Upload
1. **Trigger:** Group admin taps "Change Cover" in Group Settings.
2. **Client-Side Processing:** Image cropped to 16:9 aspect ratio. Compressed to max 1200px width.
3. **Upload:** `POST /api/files/upload` with `file_type` = `cover`.
4. **Server Processing:** Validates, converts to WebP, stores. Returns public URL (covers are not private).
5. **Link to Record:** `PATCH /api/groups/{id}` with `{ cover_file_id: file_id }`.

### D. Comment Attachment Upload
1. **Trigger:** User taps attach icon in comment input bar (Story 21).
2. **Client-Side Processing:** Compressed to max 2048px width.
3. **Upload:** `POST /api/files/upload` with `file_type` = `attachment`.
4. **Server Processing:** Standard pipeline. Returns file_id. Comment creation payload includes `image_file_id`.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### `ImagePickerBottomSheet`
- Two options: Camera icon + "Take Photo", Gallery icon + "Choose from Gallery".
- Rounded bottom sheet with 16px padding. Each option is a ListTile with leading icon.

### `UploadProgressIndicator`
- Circular progress indicator overlaid on the image preview during upload.
- Shows percentage (0-100%). On completion, checkmark animation for 500ms.
- On failure, red X icon with "Retry" tap target.

### `ImagePreviewThumbnail`
- Used in expense cards and comment bubbles. 120x80px rounded rectangle.
- Tap to expand to full-screen viewer with pinch-to-zoom (`photo_view` Flutter package).
- Placeholder shimmer while loading. Broken image icon if load fails.

### `AvatarCropperScreen`
- Full-screen crop interface. Circular crop overlay for avatars. Drag to reposition, pinch to zoom.
- "Cancel" and "Done" buttons in app bar.

---

## 5. Technical Architecture & Database

### Storage Strategy
- **Development:** Local filesystem. Files stored in `uploads/` directory relative to backend root. Served via Fastify static file plugin (`@fastify/static`).
- **Production:** S3-compatible object storage (Hetzner Object Storage or self-hosted MinIO on VPS). Accessed via `@aws-sdk/client-s3` (compatible with any S3 API).
- **Abstraction:** A `StorageService` interface with two implementations (`LocalStorageAdapter`, `S3StorageAdapter`). Selected via `STORAGE_DRIVER` env variable.

### Upload Pipeline (Server)
```
Client multipart POST
  -> @fastify/multipart (stream mode, 5MB limit)
  -> MIME type validation (magic bytes, not just Content-Type header)
  -> sharp: resize to type-specific max dimensions
  -> sharp: convert to WebP (quality 80)
  -> sharp: generate thumbnail if receipt/attachment
  -> StorageService.upload(buffer, path)
  -> Insert record into `files` table
  -> Return { file_id, url }
```

### Backend Endpoints

#### 1. `POST /api/files/upload`
- **Auth:** Required (JWT).
- **Content-Type:** `multipart/form-data`.
- **Fields:** `file` (binary), `file_type` (enum: avatar, receipt, cover, attachment).
- **Validation:**
  - File size <= 5MB (enforced by `@fastify/multipart` `limits.fileSize`).
  - MIME type must be `image/jpeg`, `image/png`, or `image/webp`.
  - MIME validated by reading magic bytes with `file-type` npm package (not trusting client header).
- **Processing:** Compress and convert via `sharp` based on `file_type` dimensions.
- **Response:** `{ file_id: "uuid", url: "https://...", thumbnail_url: "https://..." | null }`.
- **Error Responses:** `400` invalid file type, `413` file too large, `415` unsupported media type.

#### 2. `GET /api/files/:file_id/signed-url`
- **Auth:** Required. User must have access (group member for receipts/attachments, or file owner).
- **Response:** `{ url: "https://...?signature=...&expires=...", expires_at: "ISO8601" }`.
- **Expiry:** 1 hour for receipts, 1 hour for attachments.

#### 3. `DELETE /api/files/:file_id`
- **Auth:** Required. Only file uploader or group admin can delete.
- **Behavior:** Soft-delete (marks `deleted_at`). Background job physically removes file from storage after 7 days.

### Database Schema (Prisma)
```prisma
model File {
  id            String    @id @default(uuid())
  uploaderId    String    @map("uploader_id")
  fileType      FileType  @map("file_type")
  storagePath   String    @map("storage_path")
  thumbnailPath String?   @map("thumbnail_path")
  publicUrl     String?   @map("public_url")
  mimeType      String    @map("mime_type")
  sizeBytes     Int       @map("size_bytes")
  linkedTo      String?   @map("linked_to")  // "user:uuid" or "expense:uuid" or "group:uuid" or "comment:uuid"
  deletedAt     DateTime? @map("deleted_at")
  createdAt     DateTime  @default(now()) @map("created_at")

  uploader      User      @relation(fields: [uploaderId], references: [id])

  @@map("files")
}

enum FileType {
  AVATAR
  RECEIPT
  COVER
  ATTACHMENT
}
```

### CDN & Caching
- **Public files (avatars, group covers):** Served via public URL. Cloudflare caches with `Cache-Control: public, max-age=86400`. Cache busted by changing filename on re-upload (UUID-based names ensure uniqueness).
- **Private files (receipts, attachments):** Accessed via signed URLs. Cloudflare configured to NOT cache signed URLs (`Cache-Control: private, no-store`).

### Orphan Cleanup (BullMQ)
- **Job name:** `file:cleanup-orphans`.
- **Schedule:** Runs every hour via BullMQ repeatable job.
- **Logic:** Query `files` table for records where `linked_to IS NULL AND created_at < NOW() - INTERVAL 24 HOURS`. Delete from storage, then delete database record.
- **Safety:** Files only become "linked" when the parent record (user, expense, comment) is updated to reference them. If a user uploads but never submits the form, the file remains orphaned.

### File Organization in Storage
```
uploads/
  avatars/
    {user_id}/{file_id}.webp
  receipts/
    {group_id}/{file_id}.webp
    {group_id}/{file_id}_thumb.webp
  covers/
    {group_id}/{file_id}.webp
  attachments/
    {group_id}/{file_id}.webp
    {group_id}/{file_id}_thumb.webp
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Corrupt file upload** | User uploads a truncated JPEG (download interrupted). | `sharp` throws on processing. Backend returns `400: File could not be processed`. Client shows "Upload failed — try again with a different image." |
| **Duplicate upload** | User taps upload twice rapidly. | Frontend disables upload button after first tap. Backend uses idempotency key in the multipart request to prevent duplicate storage. Returns existing file_id if duplicate detected. |
| **Storage full** | S3 bucket or disk reaches capacity. | `StorageService.upload()` throws. Backend returns `503: Storage temporarily unavailable`. Alert fires via monitoring (Story 14). |
| **File referenced by multiple records** | Receipt attached to an expense AND referenced in a comment. | `linked_to` stores the primary reference. Soft-delete checks all references before marking as orphaned. A `file_references` junction approach may be needed if multi-reference is common. |
| **MIME type spoofing** | Attacker renames `malware.exe` to `photo.jpg`. | Server reads magic bytes via `file-type` package. Actual MIME does not match allowed list. Returns `415: Unsupported file type`. |
| **Very large image (50MP camera)** | User uploads a 20MB raw photo. | Client-side compression reduces to under 5MB before upload. If still over 5MB after client compression, upload is blocked with "Image too large" message. |
| **Upload during poor network** | Upload stalls halfway on mobile data. | Client implements chunked upload timeout (30 seconds). Shows retry button. Backend discards incomplete multipart streams. |
| **Old avatar cleanup** | User changes avatar 5 times. | Each time, old avatar's `linked_to` is cleared. Orphan cleanup job removes them after 24 hours. |

---

## 7. Final QA Acceptance Criteria

- [ ] Uploading a JPEG, PNG, or WebP image under 5MB succeeds and returns a valid URL.
- [ ] Uploading a file over 5MB returns `413` error with a user-friendly message.
- [ ] Uploading a non-image file (PDF, ZIP, EXE) returns `415` error regardless of file extension.
- [ ] Uploaded images are converted to WebP format on the server.
- [ ] Avatar uploads are resized to max 256x256px.
- [ ] Receipt uploads generate both full-size (max 2048px) and thumbnail (400px) versions.
- [ ] Signed URLs for receipts expire after 1 hour and return `403` after expiry.
- [ ] Public avatar URLs are accessible without authentication.
- [ ] Orphaned files (uploaded but never linked) are deleted after 24 hours.
- [ ] Switching between local storage (dev) and S3 storage (prod) requires only changing the `STORAGE_DRIVER` env variable.
- [ ] Deleting a user's account removes all their uploaded files from storage.
- [ ] Upload progress is shown in the UI with percentage indicator.
