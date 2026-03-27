# Story 13: Offline Sync & Resilience - Detailed Execution Plan

## 1. Core Objective & Philosophy
Ensure the application never loses user data due to poor network conditions, and handle conflicting multi-device states seamlessly. The app must feel reliable even on a subway or airplane. Users should be able to add expenses, settle debts, and leave comments while fully offline, with all actions queued locally and synced transparently when connectivity returns.

---

## 2. Target Persona & Motivation
- **The Commuter:** Tries to log an expense or settle a debt while on a train with spotty 3G. They cannot afford for the app to crash or "forget" the $100 they just entered.
- **The Traveler:** Abroad with no data plan, needs to split dinner costs with friends right now and trust the app will sync later.
- **The Multi-Device User:** Has the app open on their phone and tablet simultaneously. Expects changes on one device to appear on the other within seconds.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Offline Detection & Banner Display
1. **Trigger:** Device loses network connectivity (airplane mode, tunnel, dead zone).
2. **System State - Detection:** The `connectivity_plus` Flutter package detects the connectivity change via its `onConnectivityChanged` stream. The app listens to this stream at the top-level `MaterialApp` widget.
3. **Action - UI Behavior:** A persistent yellow `OfflineBanner` slides down from the top of the screen: "You are offline. Changes will sync when connected." The banner remains until connectivity is restored.
4. **System State - App Mode:** The app transitions into "offline mode" internally. All mutation API calls are intercepted by the sync service and routed to the local queue instead.

### B. Offline Expense Entry (Action Queue)
1. **Trigger:** User is offline, enters an expense, and taps "Save".
2. **System State - Local Queue:** The sync service serializes the full API payload and writes a new row into the local SQLite database (`action_queue` table) with status `pending`.
3. **Action - Optimistic UI:** The expense appears immediately in the user's expense list and balance calculations, rendered with a small clock icon indicating "pending sync". The balance updates optimistically on screen.
4. **Action - Toast:** A brief yellow toast appears: "Saved locally. Will sync when connected."

### C. Auto-Sync on Reconnect
1. **Trigger:** `connectivity_plus` fires a connectivity change event indicating network is available.
2. **System State - Validation:** The sync service performs a lightweight ping to `GET /api/health` to confirm actual internet access (not just WiFi with no internet).
3. **System State - Queue Processing:** The sync service reads all `pending` actions from the `action_queue` table in FIFO order (sorted by `created_at`). For each action:
   - Set status to `syncing`.
   - Fire the original API request with the stored payload, including the `Idempotency-Key` header.
   - On `2xx` response: delete the row from the queue, update the local UI to remove the pending indicator.
   - On `4xx` client error (non-retryable): mark as `failed`, notify the user.
   - On `5xx` or network error: increment `retry_count`, apply exponential backoff, re-mark as `pending`.
4. **Action - UI Reaction:** The yellow `OfflineBanner` disappears. Pending clock icons resolve to normal state. A green toast confirms: "All changes synced."

### D. Multi-Device Real-Time Sync
1. **Trigger:** User has the app open on phone and tablet simultaneously.
2. **Action:** User settles a debt on their phone.
3. **System State - Server Push:** The backend commits the settlement, then emits a Socket.io event (`balance:updated`, `expense:created`, etc.) to all connected clients for the affected users.
4. **System State - Client Reaction:** The tablet receives the Socket.io event. The local state manager processes the payload and re-renders the affected screens instantly: the debt drops to $0.00 before the user's eyes.
5. **Reconnection Delta Sync:** When a client reconnects after being offline, it sends its `last_sync_timestamp` to the server. The server returns all changes (expenses, settlements, group updates) that occurred after that timestamp, allowing the client to catch up without a full reload.

---

## 4. UI/UX Component Specifications

### `OfflineBanner`
- A thin, persistent amber-colored strip pinned to the top of the viewport (below the app bar).
- Contains a WiFi-off icon and text: "You are offline. Changes will sync when connected."
- Animates in/out with a `SlideTransition` (300ms ease-in-out).
- Z-index ensures it floats above scrollable content.

### `PendingSyncIcon`
- A small clock icon (`Icons.access_time`) rendered in muted grey, positioned next to the timestamp of any locally-queued item.
- Tooltip on long-press: "This change hasn't synced to the server yet."
- Transitions to a green checkmark briefly (1s) when sync completes, then disappears.

### `SyncFailedCard`
- Shown in a dedicated "Sync Issues" section accessible from Settings or via a banner tap.
- Each failed action displays: action type, description, failure reason, and a "Retry" button.
- A "Discard" button allows the user to permanently remove a failed action after confirmation.

### `SyncStatusIndicator`
- Small dot in the app bar (green = synced, yellow = syncing, red = sync issues).
- Tapping it opens a bottom sheet showing queue status: "3 changes pending", "All synced", or "2 items failed".

---

## 5. Technical Architecture

### Flutter Client Architecture

#### Connectivity Detection
```dart
// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged =>
    _connectivity.onConnectivityChanged.map(
      (result) => result != ConnectivityResult.none,
    );

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

#### Local SQLite Queue (using drift)
```dart
// lib/database/tables.dart
class ActionQueue extends Table {
  TextColumn get id => text()();                   // UUID v4
  TextColumn get type => text()();                 // add_expense | settle | comment | edit_expense | delete_expense
  TextColumn get payload => text()();              // JSON-serialized API request body
  TextColumn get endpoint => text()();             // e.g., POST /api/expenses
  TextColumn get idempotencyKey => text()();       // UUID v4, sent as header
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending | syncing | failed
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### Sync Service
```dart
// lib/services/sync_service.dart
class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;

  static const int _maxRetries = 5;
  static const Duration _maxBackoff = Duration(seconds: 30);

  Future<void> enqueueAction({
    required String type,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final action = ActionQueueCompanion.insert(
      id: const Uuid().v4(),
      type: type,
      endpoint: endpoint,
      payload: jsonEncode(payload),
      idempotencyKey: const Uuid().v4(),
      createdAt: DateTime.now(),
    );
    await _db.into(_db.actionQueue).insert(action);
  }

  Future<void> processQueue() async {
    final pending = await (_db.select(_db.actionQueue)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
    ).get();

    for (final action in pending) {
      await _processAction(action);
    }
  }

  Future<void> _processAction(ActionQueueData action) async {
    // Mark as syncing
    await (_db.update(_db.actionQueue)
      ..where((t) => t.id.equals(action.id))
    ).write(const ActionQueueCompanion(status: Value('syncing')));

    try {
      await _apiClient.request(
        action.endpoint,
        data: jsonDecode(action.payload),
        headers: {'Idempotency-Key': action.idempotencyKey},
      );
      // Success: remove from queue
      await (_db.delete(_db.actionQueue)
        ..where((t) => t.id.equals(action.id))
      ).go();
    } on DioException catch (e) {
      if (e.response?.statusCode != null && e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
        // Client error, non-retryable
        await (_db.update(_db.actionQueue)
          ..where((t) => t.id.equals(action.id))
        ).write(ActionQueueCompanion(
          status: const Value('failed'),
          errorMessage: Value(e.response?.data?.toString()),
        ));
      } else {
        // Server error or network issue, retry with backoff
        final newRetryCount = action.retryCount + 1;
        if (newRetryCount >= _maxRetries) {
          await (_db.update(_db.actionQueue)
            ..where((t) => t.id.equals(action.id))
          ).write(ActionQueueCompanion(
            status: const Value('failed'),
            retryCount: Value(newRetryCount),
            errorMessage: const Value('Max retries exceeded'),
          ));
        } else {
          final backoff = Duration(
            seconds: math.min(math.pow(2, newRetryCount).toInt(), _maxBackoff.inSeconds),
          );
          await Future.delayed(backoff);
          await (_db.update(_db.actionQueue)
            ..where((t) => t.id.equals(action.id))
          ).write(ActionQueueCompanion(
            status: const Value('pending'),
            retryCount: Value(newRetryCount),
          ));
        }
      }
    }
  }
}
```

### Node.js Fastify Backend

#### Idempotency Middleware
```javascript
// src/plugins/idempotency.js
const fp = require('fastify-plugin');

async function idempotencyPlugin(fastify) {
  const redis = fastify.redis;

  fastify.addHook('preHandler', async (request, reply) => {
    if (['POST', 'PUT', 'PATCH'].includes(request.method)) {
      const key = request.headers['idempotency-key'];
      if (!key) return; // Idempotency is optional but honored

      const cached = await redis.get(`idempotency:${key}`);
      if (cached) {
        const parsed = JSON.parse(cached);
        reply.code(parsed.statusCode).send(parsed.body);
        return reply;
      }
    }
  });

  fastify.addHook('onSend', async (request, reply, payload) => {
    if (['POST', 'PUT', 'PATCH'].includes(request.method)) {
      const key = request.headers['idempotency-key'];
      if (key && reply.statusCode >= 200 && reply.statusCode < 300) {
        await redis.set(
          `idempotency:${key}`,
          JSON.stringify({ statusCode: reply.statusCode, body: payload }),
          'EX', 86400 // 24 hour TTL
        );
      }
    }
    return payload;
  });
}

module.exports = fp(idempotencyPlugin);
```

#### Delta Sync Endpoint
```javascript
// src/routes/sync.js
async function syncRoutes(fastify) {
  fastify.get('/api/sync/delta', {
    preValidation: [fastify.authenticate],
    schema: {
      querystring: {
        type: 'object',
        properties: {
          since: { type: 'string', format: 'date-time' },
        },
        required: ['since'],
      },
    },
  }, async (request, reply) => {
    const { since } = request.query;
    const userId = request.user.id;
    const sinceDate = new Date(since);

    const [expenses, settlements, groups] = await Promise.all([
      fastify.prisma.expense.findMany({
        where: {
          participants: { some: { userId } },
          updatedAt: { gt: sinceDate },
        },
        include: { participants: true },
      }),
      fastify.prisma.settlement.findMany({
        where: {
          OR: [{ payerId: userId }, { payeeId: userId }],
          updatedAt: { gt: sinceDate },
        },
      }),
      fastify.prisma.group.findMany({
        where: {
          members: { some: { userId } },
          updatedAt: { gt: sinceDate },
        },
      }),
    ]);

    return {
      expenses,
      settlements,
      groups,
      server_time: new Date().toISOString(),
    };
  });
}

module.exports = syncRoutes;
```

#### Socket.io Real-Time Push
```javascript
// src/plugins/socketio.js
// On expense creation, settlement, etc.:
function notifyAffectedUsers(io, userIds, event, data) {
  for (const userId of userIds) {
    io.to(`user:${userId}`).emit(event, data);
  }
}

// Events emitted:
// 'expense:created'   — new expense added
// 'expense:updated'   — expense edited
// 'expense:deleted'   — expense removed
// 'settlement:created' — debt settled
// 'balance:updated'   — recalculated balances
// 'group:updated'     — group membership or settings changed
```

### Conflict Resolution Strategy

**Last-Write-Wins with Server Timestamps:**
- Every mutable record has an `updatedAt` field managed by the server.
- When a queued action arrives, the server compares the record's current `updatedAt` against the client's `base_updated_at` (included in the payload).
- If the server's `updatedAt` is newer than the client's `base_updated_at`, a conflict exists.
- The server applies the change (last-write-wins) but includes a `conflict: true` flag in the response.
- The client displays a notification: "This item was modified by another user. Your version was applied."
- For delete conflicts (client edits a deleted record), the server returns `410 Gone` and the client removes it locally with a notification.

---

## 6. Edge Cases & Error Handling

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Conflicting offline edits** | User A edits expense to $10 offline, User B edits same expense to $20 offline. Both reconnect. | Last-write-wins based on server arrival timestamp. The second sync receives a `conflict: true` flag. User is notified: "This expense was also modified by User B." |
| **Offline delete + offline edit** | User A deletes an expense offline. User B edits the same expense offline. Both reconnect. | Delete processes first. User B's edit hits `410 Gone`. Client removes the expense locally and shows: "This expense was deleted by another user." |
| **Corrupted local SQLite queue** | SQLite database becomes corrupted on disk. | Sync service wraps all DB operations in try-catch. On corruption, the queue table is recreated (empty). User is notified: "Some pending changes could not be recovered." App continues functioning. |
| **Duplicate sync on flaky connection** | Request succeeds server-side but client times out before receiving response. Client retries. | Idempotency key on the retry matches the original. Server returns the cached successful response without re-processing. |
| **Queue grows very large (100+ items)** | User is offline for an extended period, queuing many actions. | Queue processes in batches of 10 with 500ms delay between batches to avoid overwhelming the server. A progress indicator shows "Syncing 15 of 47 changes..." |
| **App killed while syncing** | OS kills the app mid-sync. Some items are in `syncing` state. | On next app launch, all `syncing` items are reset to `pending` and the queue restarts. Idempotency keys prevent duplicates. |
| **Clock skew between devices** | User's phone clock is 5 minutes off from server time. | All conflict resolution uses server-assigned timestamps, never client timestamps. `base_updated_at` is always a value originally received from the server. |

---

## 7. QA Acceptance Criteria

- [ ] `connectivity_plus` correctly detects offline/online transitions on iOS, Android, and Web.
- [ ] Adding an expense while offline saves it to the local SQLite queue with status `pending`.
- [ ] The expense appears immediately in the UI with a clock icon indicating pending sync.
- [ ] When connectivity returns, all queued actions are sent to the server in FIFO order.
- [ ] Successful sync removes the pending indicator and shows a green confirmation.
- [ ] Failed actions (after 5 retries with exponential backoff: 1s, 2s, 4s, 8s, 16s capped at 30s) are marked as `failed` with a user-visible notification.
- [ ] Idempotency keys prevent duplicate expense creation on retry after timeout.
- [ ] Socket.io pushes real-time updates to all connected clients for the same user.
- [ ] Delta sync endpoint returns all changes since the provided timestamp.
- [ ] Conflict resolution notifies the user when their change conflicts with a newer server version.
- [ ] The `OfflineBanner` appears within 1 second of losing connectivity and disappears within 1 second of restoration.
- [ ] The `SyncStatusIndicator` accurately reflects queue state (synced/syncing/failed).
- [ ] App restart recovers gracefully: `syncing` items reset to `pending`, queue resumes processing.
- [ ] No data loss occurs during any offline/online transition scenario.
