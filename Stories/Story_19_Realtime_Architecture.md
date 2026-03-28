# Story 30: Real-time Architecture (WebSocket / Socket.io) - Detailed Execution Plan

## 1. Core Objective & Philosophy
Enable instant updates across all connected clients. When Alice adds an expense, Bob sees it immediately without refreshing. Real-time is not a luxury feature — in a financial app where balances change, stale data causes confusion and disputes. Every mutation that affects another user's view must propagate in real-time.

---

## 2. Target Persona & Motivation
- **The Active Group Member:** Alice adds a $60 dinner expense while sitting across from Bob. Bob should see his $30 share appear on his phone within 1 second, not after a pull-to-refresh.
- **The Settlement Watcher:** Charlie just paid Alice $100. Alice should see the settlement confirmation instantly, giving her confidence the payment was logged.
- **The Comment Responder:** Bob posts "Was this the restaurant on 5th Ave?" on an expense. Alice, viewing the same expense, sees the comment appear live without reloading.

---

## 3. Comprehensive Step-by-Step User Journey

### A. Real-time Expense Creation
1. **Trigger:** Alice creates a $60 expense in "Tokyo Trip" group, splitting equally with Bob and Charlie.
2. **Backend Processing:** Expense is saved to database. Balances recalculated. Backend emits Socket.io events.
3. **Events Emitted:**
   - `expense:created` to room `group:tokyo-trip-id` (all group members' connected clients receive it).
   - `balance:updated` to room `group:tokyo-trip-id` with new balance summary.
   - `notification:new` to rooms `user:bob-id` and `user:charlie-id` (personal notification).
4. **Bob's Client:** Riverpod provider listening on `expense:created` adds the expense to local state. Group ledger updates instantly. Balance widget refreshes. No loading spinner, no manual refresh.
5. **Charlie's Client (on dashboard, not in group):** Receives `notification:new` and `balance:updated`. Dashboard balance summary updates. Notification bell shows unread count.

### B. Real-time Settlement
1. **Trigger:** Bob settles $30 with Alice via the app.
2. **Events Emitted:**
   - `settlement:created` to room `group:tokyo-trip-id`.
   - `balance:updated` to room `group:tokyo-trip-id`.
   - `notification:new` to room `user:alice-id`.
3. **Alice's Client:** Settlement appears in group ledger. Balance with Bob updates to $0. Notification toast slides in: "Bob settled $30 with you."

### C. Real-time Comments
1. **Trigger:** Bob comments "Do you have the receipt?" on an expense.
2. **Events Emitted:** `comment:created` to room `group:tokyo-trip-id` with expense ID.
3. **Alice's Client (viewing same expense):** Comment appears instantly in the thread. Scroll position maintained if at bottom.
4. **Charlie's Client (not viewing expense):** Receives `notification:new` only. Comment loads when he opens the expense detail.

### D. Member Join/Leave
1. **Trigger:** David joins the group via an invite link (Story 31).
2. **Events Emitted:** `member:joined` to room `group:tokyo-trip-id` with David's profile info.
3. **All Clients:** Group member list updates. "David joined the group" activity entry appears.

---

## 4. Ultra-Detailed UI/UX Component Specifications

### `ConnectionStatusIndicator`
- Small dot in the app bar or bottom nav. Green = connected. Yellow = reconnecting. Red = disconnected.
- Only visible when NOT connected (green state is hidden to avoid clutter).
- Tapping shows a bottom sheet: "Real-time connection lost. Retrying..." with a manual "Retry Now" button.

### `RealtimeToast`
- Slide-down toast notification for events received while the user is actively using the app.
- Shows for 3 seconds, then auto-dismisses. Tappable to navigate to relevant screen.
- Examples: "Bob added 'Dinner' - you owe $30", "Alice settled $50 with you."
- Does NOT show for events the current user initiated (no self-toasts).

### `LiveUpdateShimmer`
- When a new expense appears via real-time event, the card briefly highlights with a subtle blue pulse animation (300ms) to draw attention.
- Applied to: new expense cards, updated balance amounts, new comments.

---

## 5. Technical Architecture & Database

### Server Setup (Fastify + Socket.io)
```typescript
// server.ts
import Fastify from 'fastify';
import fastifySocketIO from 'fastify-socket.io';

const app = Fastify();

app.register(fastifySocketIO, {
  cors: {
    origin: process.env.CORS_ORIGIN,
    credentials: true,
  },
  // For multi-server scaling:
  // adapter: createAdapter(redisClient, redisSub),
});

app.ready().then(() => {
  app.io.use(async (socket, next) => {
    // Authentication middleware
    const token = socket.handshake.auth.token;
    try {
      const user = await verifyJWT(token);
      socket.data.userId = user.id;
      next();
    } catch (err) {
      next(new Error('Authentication failed'));
    }
  });

  app.io.on('connection', (socket) => {
    // Auto-join personal room
    socket.join(`user:${socket.data.userId}`);

    // Client requests to join a group room
    socket.on('group:join', async (groupId) => {
      const isMember = await checkGroupMembership(socket.data.userId, groupId);
      if (isMember) {
        socket.join(`group:${groupId}`);
      }
    });

    // Client leaves a group room
    socket.on('group:leave', (groupId) => {
      socket.leave(`group:${groupId}`);
    });

    socket.on('disconnect', () => {
      // Cleanup handled automatically by Socket.io
    });
  });
});
```

### Client Setup (Flutter)
```dart
// socket_service.dart
class SocketService {
  late IO.Socket socket;

  void connect(String token) {
    socket = IO.io('https://api.yourdomain.com',
      IO.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(30000)
        .build()
    );
  }

  void joinGroup(String groupId) {
    socket.emit('group:join', groupId);
  }

  void leaveGroup(String groupId) {
    socket.emit('group:leave', groupId);
  }
}
```

### Event Schema
Every event emitted by the server follows a consistent schema:

```typescript
interface SocketEvent<T> {
  event: string;           // e.g., "expense:created"
  data: T;                 // Event-specific payload
  timestamp: string;       // ISO 8601, used for delta sync on reconnect
  actorId: string;         // User who triggered the event
}
```

### Event Catalog

| Event | Room | Payload | Triggered By |
| --- | --- | --- | --- |
| `expense:created` | `group:{id}` | `{ expense: ExpenseSummary }` | POST /api/expenses |
| `expense:updated` | `group:{id}` | `{ expense: ExpenseSummary }` | PATCH /api/expenses/:id |
| `expense:deleted` | `group:{id}` | `{ expenseId: string }` | DELETE /api/expenses/:id |
| `settlement:created` | `group:{id}` | `{ settlement: SettlementSummary }` | POST /api/settlements |
| `balance:updated` | `group:{id}` | `{ balances: BalanceSummary[] }` | Any expense/settlement change |
| `comment:created` | `group:{id}` | `{ expenseId, comment: Comment }` | POST /api/expenses/:id/comments |
| `notification:new` | `user:{id}` | `{ notification: Notification }` | Any event targeting a user |
| `member:joined` | `group:{id}` | `{ member: UserSummary }` | POST /api/groups/:id/join |
| `member:left` | `group:{id}` | `{ userId: string }` | POST /api/groups/:id/leave |

### Emitting Events from API Handlers
Events are emitted AFTER the database transaction commits successfully. Never emit before commit (could send events for rolled-back data).

```typescript
// In expense creation handler:
await prisma.$transaction(async (tx) => {
  const expense = await tx.expense.create({ ... });
  await tx.balance.updateMany({ ... });
  return expense;
});

// Only after transaction succeeds:
app.io.to(`group:${groupId}`).emit('expense:created', {
  event: 'expense:created',
  data: { expense: expenseSummary },
  timestamp: new Date().toISOString(),
  actorId: userId,
});
```

### Room Strategy

| Room Pattern | Who Joins | When |
| --- | --- | --- |
| `user:{userId}` | The user themselves | On socket connection (automatic) |
| `group:{groupId}` | Group members | When navigating to group screen (client emits `group:join`) |

- Users leave group rooms when navigating away (`group:leave`).
- Personal rooms persist for the entire connection lifetime.
- Group membership is verified server-side before allowing room join.

### Reconnection & Delta Sync
1. **Auto-reconnect:** Socket.io client handles reconnection with exponential backoff (1s, 2s, 4s, ... max 30s).
2. **Delta sync on reconnect:** Client stores `lastEventTimestamp` locally. On reconnect, emits `sync:delta` with the timestamp.
3. **Server responds:** Queries events since that timestamp from a short-lived event log (Redis sorted set, TTL 1 hour). Returns missed events.
4. **Fallback:** If delta sync fails or gap is too large (> 1 hour), client does a full data refresh via REST API.

```typescript
// Server-side delta sync handler
socket.on('sync:delta', async (lastTimestamp: string) => {
  const missedEvents = await redis.zrangebyscore(
    `events:user:${socket.data.userId}`,
    new Date(lastTimestamp).getTime(),
    '+inf'
  );
  socket.emit('sync:delta:response', missedEvents.map(JSON.parse));
});
```

### Scaling with Redis Adapter
- **Single server:** Default Socket.io in-memory adapter. No extra configuration.
- **Multi-server (Hetzner LB):** Install `@socket.io/redis-adapter`. All server instances connect to the same Redis instance. Events emitted on one server propagate to clients connected to other servers.

```typescript
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();
await Promise.all([pubClient.connect(), subClient.connect()]);

app.io.adapter(createAdapter(pubClient, subClient));
```

### Rate Limiting
- **Inbound:** Max 50 events per second per connection. Implemented via Socket.io middleware that tracks event count per socket in a sliding window.
- **Outbound:** No limit (server-to-client events are controlled by application logic).
- **Abuse detection:** If a client exceeds rate limit 3 times in 1 minute, disconnect with reason `rate_limit_exceeded`.

### Flutter State Management Integration (Riverpod)
```dart
// expense_realtime_provider.dart
final expenseRealtimeProvider = StreamProvider.family<Expense, String>((ref, groupId) {
  final socket = ref.watch(socketServiceProvider);
  return socket.on('expense:created')
    .where((data) => data['groupId'] == groupId)
    .map((data) => Expense.fromJson(data['expense']));
});

// In the group screen widget:
ref.listen(expenseRealtimeProvider(groupId), (prev, next) {
  next.whenData((expense) {
    // Add to local expense list, trigger UI rebuild
    ref.read(groupExpensesProvider(groupId).notifier).addExpense(expense);
  });
});
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Backend |
| --- | --- | --- |
| **Token expiry mid-connection** | User's JWT expires while socket is connected. | Server-side middleware validates token on every inbound event (not just on connect). On next event after expiry, server emits `auth:expired` and disconnects. Client catches this, refreshes JWT via refresh token, reconnects automatically. |
| **Server restart** | Backend process restarts (deployment, crash). | All socket connections drop. Clients auto-reconnect. On reconnect, delta sync fetches missed events from Redis event log. |
| **Client backgrounded (mobile)** | User switches to another app. OS may kill the socket. | Flutter detects app lifecycle via `WidgetsBindingObserver`. On `resumed`, checks socket connection state. If disconnected, reconnects and delta syncs. |
| **Stale room subscriptions** | User is kicked from a group but still has the socket in the group room. | When a member is removed, backend explicitly removes their socket from the group room via `app.io.in(\`user:\${userId}\`).socketsLeave(\`group:\${groupId}\`)`. Also emits `group:kicked` to the user's personal room. |
| **Duplicate events** | Network hiccup causes event to be received twice. | Each event includes a unique `eventId`. Client maintains a Set of recently processed event IDs (last 100). Duplicates are silently dropped. |
| **High-latency connection** | User on very slow mobile data (500ms+ latency). | Socket.io handles this transparently. Events queue and deliver in order. UI remains responsive because state updates are optimistic. |
| **Corporate firewall blocks WebSocket** | WebSocket upgrade fails behind restrictive proxy. | Socket.io automatically falls back to HTTP long polling. Slightly higher latency but fully functional. No user action required. |
| **Massive group (50+ members)** | An event in a large group fans out to many connections. | Socket.io room broadcast is efficient (single write, multiple deliveries). Redis adapter handles cross-server fan-out. If performance becomes an issue, batch `balance:updated` events with a 500ms debounce. |
| **User has multiple devices** | Alice is logged in on phone and laptop simultaneously. | Both devices join the same `user:{userId}` room. Both receive all personal events. Group rooms are joined independently per device based on which screen is active. |

---

## 7. Final QA Acceptance Criteria

- [ ] When Alice creates an expense, Bob sees it appear in the group ledger within 2 seconds (without refreshing).
- [ ] When a settlement is created, the balance widget updates in real-time for all group members.
- [ ] New comments appear instantly in the expense detail comment thread for all viewers.
- [ ] Socket connection requires valid JWT. Connecting without a token is rejected immediately.
- [ ] Joining a group room without being a member of that group is rejected.
- [ ] After losing connection (airplane mode toggle), client reconnects and receives missed events via delta sync.
- [ ] Connection status indicator shows yellow during reconnection and disappears when connected.
- [ ] Events initiated by the current user do not trigger self-toasts (no "You added an expense" toast).
- [ ] Rate limiting disconnects a client sending more than 50 events/second.
- [ ] With Redis adapter enabled, events emitted from Server A reach clients connected to Server B.
- [ ] Mobile app backgrounded for 5 minutes reconnects and syncs on resume without data loss.
- [ ] A user removed from a group immediately stops receiving events from that group's room.
