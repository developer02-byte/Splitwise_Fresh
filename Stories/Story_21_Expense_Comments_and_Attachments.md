# Story 21: Expense Comments & Receipt Attachments - Detailed Execution Plan

## 1. Core Objective & Philosophy
Add a social, audit-trail layer to expenses. Group members frequently need to ask "Wait, what was this $45 charge?" A comment thread answers this permanently on the expense record instead of via WhatsApp, which is lost forever.

---

## 2. Target Persona & Motivation
- **The Skeptic:** John sees "$45 - Gas" and wonders if Bob actually filled the tank. Bob replies with a receipt photo comment. Dispute resolved in the app, not over text.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Viewing & Adding a Comment
1. **Trigger:** User taps an expense from the Group Ledger or Activity Feed. Routed to Expense Detail Screen `/expenses/{id}`.
2. **UI Layout:** Top section: Expense summary (amount, payer, split). Middle: `CommentThreadList`. Bottom: Sticky `CommentInputBar`.
3. **Action - Type & Post:** User types "Do you have the receipt?" and taps the send icon.
4. **System State - Send:** `POST /api/expenses/{id}/comments`. Comment instantly appears (optimistic UI). Avatar + username + text + timestamp.
5. **System State - Notification:** Push notification to all other group members on this expense: "Bob commented on 'Gas': Do you have the receipt?" (See Story 30 for WebSocket real-time notification infrastructure.)

### B. Adding a Receipt Image from Comments
1. **Trigger:** User taps the attach icon in the `CommentInputBar`.
2. **Action - File Picker:** Native file picker allows selecting an image.
3. **Action - Upload:** Image compressed and uploaded via the file storage infrastructure (see Story 28 for File Storage Infrastructure details). A thumbnail comment message appears in the thread.
4. **UI Display:** Thumbnail `120x80px` in comment bubble. Tap to expand full-screen via Flutter's `InteractiveViewer`.

---

## 4. Ultra-Detailed UI/UX Component Specifications
- **`CommentBubble`**: Avatar circle left (40px). Comment text in a rounded pill. Timestamp in muted grey below. Own comments right-aligned.
- **`CommentInputBar`**: Sticky bar fixed at bottom of screen. Text input (`Expanded` widget). Attach icon left. Send icon right (active only when input is non-empty).
- **`ReceiptAttachmentBubble`**: Compact image thumbnail rendered inline within the comment thread.

---

## 5. Technical Architecture & Database

### Backend Endpoints:
#### 1. `GET /api/expenses/{id}/comments`
- **Response:** `[{ id, user_name, avatar_url, text, image_url, created_at }]`

#### 2. `POST /api/expenses/{id}/comments`
- **Payload:** `{ text: "Do you have the receipt?", image_url: null }`

### Fastify Route Example:
```ts
// src/routes/comments.ts
fastify.post('/api/expenses/:id/comments', async (request, reply) => {
  const { id } = request.params;
  const { text, image_url } = request.body;

  const comment = await prisma.expenseComment.create({
    data: {
      expense_id: parseInt(id),
      user_id: request.userId,
      comment_text: text,
      image_url,
    },
  });

  // Notify group members via WebSocket (Story 30)
  await notifyExpenseCommentAdded(comment);

  return reply.status(201).send(comment);
});
```

### Database Context:
```sql
CREATE TABLE expense_comments (
    id SERIAL PRIMARY KEY,
    expense_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    comment_text TEXT NULL,
    image_url VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_expense FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
);
```

### Cross-Story Dependencies:
- **Story 28 (File Storage Infrastructure):** Image uploads for comment attachments use the shared file storage service defined in Story 28.
- **Story 30 (WebSocket Infrastructure):** Real-time comment notifications are delivered via the WebSocket layer defined in Story 30.

---

## 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Comment on deleted expense** | User has the comment screen open. Expense gets deleted by creator. | WebSocket event (Story 30) or next API poll returns `404`. Screen shows: "This expense has been deleted." Comment thread unmounts gracefully. |
| **Very long comment (5000 chars)** | User pastes an essay. | UI character counter activates at 800 chars. Submit blocked at `MAX_LENGTH = 1000`. Fastify backend enforces same limit via JSON schema validation. |
| **Offensive content moderation** | Out of scope for MVP. | Document as "Future Feature" — basic profanity filter can be added. |

---

## 7. Final QA Acceptance Criteria
- [ ] Posting a comment on an expense is visible to all group members without a page refresh.
- [ ] Push notification is received by all group members upon a new comment post.
- [ ] Attached receipt images are stored permanently (via Story 28 file storage) and viewable after app restart.
- [ ] Deleting an expense cascades and deletes all associated comments in the database.
- [ ] Real-time comment delivery works via WebSocket infrastructure (Story 30).
