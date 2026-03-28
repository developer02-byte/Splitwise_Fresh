# Story 19: Data Export (CSV / JSON) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Give users full ownership of their financial data. A user should be able to export their complete transaction history into a portable, readable format. This is critical for tax season, personal accounting tools, and data portability regulations (GDPR).

---

## 2. Target Persona & Motivation
- **The Accountant User:** Needs to pull all group expenses from "January 2026 - March 2026" into Excel for reimbursement reporting at work.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Export from Global Activity Feed
1. **Trigger:** User taps the `...` (three dots) menu inside the Activity tab, then "Export Data".
2. **Action - Options Modal:** A modal presents export options:
   - **Format:** `CSV` (default) | `JSON`
   - **Date Range:** `All Time` | `This Month` | `Last 3 Months` | `Custom Range`
   - **Scope:** `All Activity` | `Specific Group`
3. **Action - Export:** User taps "Download".
4. **System State - Processing:** API call `GET /api/user/export?format=csv&range=custom&from=2026-01-01&to=2026-03-31`.
5. **System State - File Generation:** Fastify backend dynamically generates the file using Node.js Readable streams and pipes it as a `Content-Disposition: attachment` response.
6. **System State - Download:** Flutter uses the `share_plus` package to open the OS share sheet, allowing the user to save the file, email it, or send it to another app.

---

## 4. Ultra-Detailed UI/UX Component Specifications
- **`ExportOptionsModal`**: Sectioned form: Format toggles (pill group), Date range (pill + date picker), Scope (dropdown). Primary "Download" button anchored to bottom.
- **`DownloadProgressBar`**: For large exports, a slim horizontal progress bar appears at the top of the screen. Disappears on completion.

---

## 5. Technical Architecture & Database

### CSV Output Format:
```
Date,Type,Description,Total Amount,Currency,Paid By,Your Share,Group,Status
2026-03-01,Expense,Rent,1200.00,USD,John Doe,400.00,Apartment 101,Unpaid
2026-03-15,Settlement,John paid you,400.00,USD,John Doe,400.00,Apartment 101,Settled
```

### Backend Endpoint:
#### 1. `GET /api/user/export`
- **Query Params:** `format=csv|json`, `from=YYYY-MM-DD`, `to=YYYY-MM-DD`, `group_id=optional`
- **Fastify Route Logic:**
  - Query all relevant `expenses` + `settlements` for user within date range using Prisma.
  - For CSV: pipe rows through `csv-stringify` (from the `csv` npm package) into a Node.js Readable stream.
  - For JSON: stream JSON array using chunked transfer encoding.
  - Set `Content-Type: text/csv` and `Content-Disposition: attachment; filename="export.csv"`.
  - Stream response directly via Fastify's `reply.send(stream)` (no temp file on server).

### Streaming Implementation (Node.js):
```ts
// src/routes/export.ts
import { stringify } from 'csv-stringify';
import { Readable } from 'stream';

fastify.get('/api/user/export', async (request, reply) => {
  const { format, from, to, group_id } = request.query;

  // Use Prisma cursor-based pagination to avoid loading all rows into memory
  const cursor = createExpenseCursor(request.userId, { from, to, group_id });

  if (format === 'csv') {
    const csvStream = stringify({ header: true, columns: CSV_COLUMNS });
    reply.header('Content-Type', 'text/csv');
    reply.header('Content-Disposition', 'attachment; filename="export.csv"');

    // Pipe rows from DB cursor through csv-stringify to response
    const readable = Readable.from(cursor);
    readable.pipe(csvStream);
    return reply.send(csvStream);
  }

  // JSON format: stream as JSON array
  reply.header('Content-Type', 'application/json');
  return reply.send(Readable.from(jsonGenerator(cursor)));
});
```

---

## 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Export with 10,000+ rows** | User exports 3 years of history. File could be large. | Backend streams the response using Node.js Readable streams without loading all rows into memory. Uses cursor-based iteration via Prisma. |
| **Special characters in descriptions** | Expense titled `Cafe & Bistro "Paris"` has commas, quotes, special chars. | CSV output via `csv-stringify` escapes all values in double quotes and doubles internal quotes per RFC 4180 standard. |
| **Export empty date range** | User selects a range with no data. | Backend returns an empty CSV/JSON with only headers. Flutter shows toast: "No data found for the selected range." |

---

## 7. Final QA Acceptance Criteria
- [ ] Exported CSV opens correctly in Microsoft Excel and Google Sheets without formatting errors.
- [ ] JSON export is valid, parseable JSON (tested via `JSON.parse()`).
- [ ] Exporting 3 years of data completes within 10 seconds.
- [ ] Descriptions with commas and quotes are correctly escaped in CSV.
- [ ] GDPR note: Export includes ALL user data — expenses created, splits owed, and settlements.
- [ ] Flutter share sheet (via `share_plus`) correctly offers save/share options for the downloaded file.
