# Story 24: Search Functionality - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Allow users to instantly locate any expense, group, or friend by typing a keyword. On a 2-year-old account with 500 expenses, "find the Airbnb charge from July" should take 2 seconds, not manual scrolling.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. Global Search Bar
1. **Trigger:** User taps the `🔍` search icon in the Top Navigation Bar.
2. **Action - Expand:** The search bar animates open. Keyboard focuses immediately.
3. **Action - Typing:** User types "Air". After a 300ms debounce, `GET /api/search?q=Air` fires.
4. **System State - Results:** A dropdown renders 3 sections: `Friends` (Alice, Carol), `Groups` (Airbnb Paris), `Expenses` (Airbnb Rental $400).
5. **Action - Selection:** User taps an Expense result → routes to Expense Detail view.

### B. In-Context Search (Within Group or Friends)
1. **Trigger:** Inside a Group Ledger, user taps a search icon at the top.
2. **Action:** The same search bar activates but scope is limited to `group_id = X`. API: `GET /api/search?q=Air&group_id=5`.

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`SearchBar`**: Full-width `TextField` widget, `48px` height, rounded pill shape via `OutlineInputBorder` with `borderRadius: 24`. Placeholder: "Search expenses, groups, friends...". Trailing `IconButton` to clear and close.
- **`SearchResultDropdown`**: Sectioned `ListView` (Friends, Groups, Expenses headings). Maximum 3 results per section. "See all results for 'Air'" `TextButton` at the bottom.
- **Debounce rule:** 300ms — prevents API spam on every keystroke. Implemented via a `Timer` or `debounce` utility in the Flutter search widget.

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoint (Fastify + Prisma):
#### 1. `GET /api/search`
- **Query Params:** `q=string`, `group_id=optional`
- **Handler Logic:**
  - Parallel queries using PostgreSQL full-text search: `to_tsvector('english', column) @@ to_tsquery('english', query)` on `expenses.title`, `groups.name`, `users.name`.
  - Prisma raw queries for full-text search: `prisma.$queryRaw` with parameterized `to_tsvector` / `to_tsquery`.
  - Limit each to 5 results for speed.
  - Return combined, categorized JSON.

### Flutter Frontend:
- **Search widget** uses a `TextEditingController` with a 300ms debounce `Timer` before calling the API via the HTTP client.
- Results displayed in a sectioned `ListView.builder`.

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **SQL injection via search** | User types `'; DROP TABLE expenses; --` | Backend uses Prisma parameterized queries. The string is treated as a literal search value, not executing SQL. |
| **Empty search / whitespace** | User hits search with no input. | No API call fires. Dropdown doesn't open. |
| **No results** | Search for "xyz123abc" finds nothing. | Dropdown shows: "No results for 'xyz123abc'. Try different keywords." |

---

## 📝 7. Final QA Acceptance Criteria ✅
- [ ] Searching "Dinner" returns all expenses with "Dinner" in the title within 300ms.
- [ ] SQL injection attempts via search are handled safely via Prisma parameterized queries.
- [ ] Search is scoped correctly when initiated from within a specific Group context.
