# [DEFERRED v1.5] Story 12: Analytics & Insights (Optional Advanced) - Detailed Execution Plan

## 🎯 1. Core Objective & Philosophy
Transform raw transactional data into actionable financial intelligence. Help users understand *where* their shared money is going, rather than just *who* they owe.

---

## 👥 2. Target Persona & Motivation
- **The Budgeter:** Wants to know if they spend too much on Food vs Travel when splitting costs with their partner over the last 6 months.

---

## 🗺️ 3. Comprehensive Step-by-Step User Journey

### A. The Group Insights View
1. **Trigger:** Inside a Group (e.g., "Seattle Trip"), user taps the "Insights" tab.
2. **Action - Render Charts:** The Flutter UI loads a donut chart (using `fl_chart` or `syncfusion_flutter_charts`) breaking spending down by category (Food 40%, Travel 30%, Lodging 30%).
3. **Action - Leaderboard:** Below the chart, a bar chart widget shows "Who Paid The Most Overall".

### B. Personal Spending Habits
1. **Trigger:** User taps "Analytics" via the Profile/Settings menu.
2. **Action - Select Range:** User selects a date range via a Flutter `showDateRangePicker` (e.g., Year to Date).
3. **System State - Processing:** `GET /api/user/analytics?range=ytd`.
4. **Action - Data Display:** Line graph widget plots total cumulative debt over time (showing spikes on weekends).

---

## 🎨 4. Ultra-Detailed UI/UX Component Specifications
- **`DonutChartWidget`**: Utilizes a Flutter charting library (e.g., `fl_chart` `PieChart`). Interacting with a slice highlights the category and displays the exact dollar amount in the center via a `Center` text widget.
- **`ExpenseCategorization`**: A prerequisite for this story. The Add Expense flow (`Story_03`) must be updated to require or infer a `category_id` (Food, Travel, Utility, etc.).

---

## 🚀 5. Technical Architecture & Database

### Backend Endpoints (Node.js Fastify):
#### 1. `GET /api/groups/{id}/analytics`
- **Handler Logic:**
  - Uses Prisma parameterized queries to aggregate expenses by category:
    ```javascript
    const analytics = await prisma.expense.groupBy({
      by: ['categoryId'],
      where: { groupId: id, deletedAt: null },
      _sum: { totalAmount: true },
    });
    ```
  - Alternatively, for complex aggregations, uses Prisma raw queries against PostgreSQL:
    ```javascript
    const result = await prisma.$queryRaw`
      SELECT category, SUM(total_amount)
      FROM expenses
      WHERE group_id = ${id} AND deleted_at IS NULL
      GROUP BY category
    `;
    ```

### Database Context (PostgreSQL):
```sql
CREATE TABLE expense_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    icon_svg VARCHAR(255)
);
-- Alter expenses table: ADD COLUMN category_id INT REFERENCES expense_categories(id);
```

### Scheduled Aggregation (Node.js):
```javascript
import cron from 'node-cron';
// Or use BullMQ recurring jobs for more robust queue-based scheduling

// Refresh materialized views every 12 hours
cron.schedule('0 */12 * * *', async () => {
  await prisma.$executeRaw`REFRESH MATERIALIZED VIEW CONCURRENTLY analytics_summary`;
  console.log('Analytics materialized view refreshed');
});
```

### PostgreSQL Materialized View:
```sql
CREATE MATERIALIZED VIEW analytics_summary AS
SELECT
    e.group_id,
    e.category_id,
    DATE_TRUNC('month', e.created_at) AS month,
    SUM(e.total_amount) AS total,
    COUNT(*) AS expense_count
FROM expenses e
WHERE e.deleted_at IS NULL
GROUP BY e.group_id, e.category_id, DATE_TRUNC('month', e.created_at);

CREATE UNIQUE INDEX ON analytics_summary (group_id, category_id, month);
```

---

## 🧨 6. Comprehensive Edge Cases & QA
| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Heavy Analytical Querying** | Calculating 3 years of expenses delays response. | Analytics routes do not query raw tables. Backend utilizes aggregated PostgreSQL materialized views updated asynchronously via Node.js scheduled jobs (node-cron or BullMQ recurring) every 12 hours. |
| **Uncategorized Data** | User never assigning categories. | The chart lumps these into a grey "Uncategorized" slice, avoiding math errors. |
