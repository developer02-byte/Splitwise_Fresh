# Real-time Contract — Socket.io Event Dictionary
> Resolves Architecture Audit Issue: #6 (Socket.io contract undefined)
> Version: 1.0 | March 26, 2026

---

## 1. CONNECTION & AUTHENTICATION

### Handshake
Socket.io uses the same HttpOnly cookie as the REST API. The access token cookie is sent automatically on the initial HTTP upgrade request (WebSocket handshake) by the browser and Flutter's cookie_jar.

```
Client → Server:
  GET /socket.io/?EIO=4&transport=websocket
  Cookie: access_token=<JWT>; refresh_token=<opaque>

Server:
  1. Extract access_token from cookie (same middleware as REST)
  2. Verify JWT signature + expiry + token_version
  3. On failure: emit 'auth_error' { code: 'TOKEN_EXPIRED' } → client triggers silent refresh → reconnects
  4. On success: attach userId to socket object → join user's personal room
```

### Reconnection Strategy
- Flutter: `socket.io/socket.io-dart` — auto-reconnect enabled
- Reconnect delay: exponential backoff (1s → 2s → 4s → 8s → max 30s)
- On reconnect: client emits `sync_request` with `last_event_id` (last known event sequence number)
- Server: responds with all events since `last_event_id` to catch up missed events
- Missed events older than 24 hours are not replayed (client triggers full refresh instead)

---

## 2. ROOM STRUCTURE

Every connected socket is automatically subscribed to the following rooms:

| Room Name | Scope | Subscribed When |
|---|---|---|
| `user:{userId}` | Personal events | Always, on connect |
| `group:{groupId}` | Group events | For each group the user is a member of |

On group membership change (join/leave): server emits `socket.join('group:{groupId}')` or `socket.leave(...)` server-side without requiring client action.

---

## 3. EVENT DICTIONARY

### 3.1 Format Convention
Every event follows this envelope:
```json
{
  "event_id": "uuid-v4",
  "timestamp": "ISO-8601",
  "actor_id": "user-uuid",
  "room": "group:abc123",
  "payload": { ... }
}
```
`event_id` is used by the client for deduplication and `last_event_id` sync.

---

### 3.2 Expense Events

**`expense:created`**
- Room: `group:{groupId}`
- Payload:
```json
{
  "expense": {
    "id": "uuid",
    "title": "Dinner at Nobu",
    "total_amount": 10000,
    "currency": "USD",
    "paid_by": [{ "user_id": "uuid", "amount": 10000 }],
    "splits": [{ "user_id": "uuid", "owed_amount": 5000 }],
    "category": "food",
    "is_recurring": false,
    "created_at": "ISO-8601"
  },
  "group_id": "uuid"
}
```
- Client action: prepend expense to group expense list; refresh user's balance totals

**`expense:updated`**
- Room: `group:{groupId}`
- Payload: same as `expense:created` (full updated object, not a diff)
- Client action: find expense by ID in local state; replace entire object; refresh balances

**`expense:deleted`**
- Room: `group:{groupId}`
- Payload:
```json
{ "expense_id": "uuid", "deleted_by": "user-uuid", "group_id": "uuid" }
```
- Client action: animate row out of list; mark as `[Deleted]` in activity feed; refresh balances

---

### 3.3 Settlement Events

**`settlement:created`**
- Room: `group:{groupId}` AND `user:{payerId}` AND `user:{payeeId}`
- Payload:
```json
{
  "settlement": {
    "id": "uuid",
    "payer_id": "uuid",
    "payee_id": "uuid",
    "amount": 4500,
    "currency": "USD",
    "group_id": "uuid or null",
    "created_at": "ISO-8601"
  }
}
```
- Client action: refresh balance for the affected friendship/group; add to activity feed

**`settlement:confirmed`**
- Room: `user:{payeeId}` only
- Sent after payment is processed server-side
- Payload: same as `settlement:created`
- Client action: show toast `"[Name] settled up with you"` + update balance

---

### 3.4 Group Events

**`group:member_joined`**
- Room: `group:{groupId}`
- Payload:
```json
{ "user": { "id": "uuid", "name": "Sara Kim", "avatar_url": "..." }, "group_id": "uuid" }
```
- Client action: append member to Members tab list; toast if ghost user converted: `"Sara Kim joined the group"`

**`group:member_left`**
- Room: `group:{groupId}`
- Payload: `{ "user_id": "uuid", "group_id": "uuid" }`
- Client action: remove member row from Members tab

**`group:member_removed`**
- Room: `group:{groupId}` AND `user:{removedUserId}`
- Payload: `{ "user_id": "uuid", "group_id": "uuid", "removed_by": "uuid" }`
- Client action: if `user_id === currentUser.id` → redirect to Groups List + toast `"You were removed from [Group Name]"`; else → remove row from Members tab

**`group:ownership_transferred`**
- Room: `group:{groupId}`
- Payload: `{ "new_owner_id": "uuid", "previous_owner_id": "uuid", "group_id": "uuid" }`
- Client action: refresh role badges in Members tab; toast `"[Name] is now the group owner"`

**`group:settings_updated`**
- Room: `group:{groupId}`
- Payload: `{ "group": { "name", "type", "currency", "default_split", "cover_photo_url" }, "group_id": "uuid" }`
- Client action: refresh group header + settings modal values

---

### 3.5 Comment Events

**`comment:created`**
- Room: `group:{groupId}`
- Payload:
```json
{
  "comment": {
    "id": "uuid",
    "expense_id": "uuid",
    "author": { "id": "uuid", "name": "Alice", "avatar_url": "..." },
    "text": "Sure, I'll pay you back",
    "image_url": null,
    "created_at": "ISO-8601"
  }
}
```
- Client action: if user currently has Expense Detail (P15) open for this expense_id → append comment; else → increment unread comment count

---

### 3.6 Notification Events

**`notification:new`**
- Room: `user:{userId}` only
- Payload:
```json
{
  "notification": {
    "id": "uuid",
    "type": "expense_added | settlement_received | payment_reminder | edit_overwritten | member_joined | comment_added",
    "title": "Alice added an expense",
    "body": "Dinner at Nobu — $50.00",
    "deep_link": "/groups/abc123/expenses/xyz456",
    "is_read": false,
    "created_at": "ISO-8601",
    "reference_id": "expense-uuid-or-null",
    "reference_type": "expense | settlement | group | null"
  }
}
```
- Client action: prepend to Notifications Center list; increment notification bell badge count

---

### 3.7 Conflict & Sync Events

**`expense:edit_conflict`**
- Room: `user:{losingUserId}` only
- Payload:
```json
{
  "expense_id": "uuid",
  "winning_user": { "id": "uuid", "name": "Alice" },
  "group_id": "uuid"
}
```
- Client action: deliver in-app notification `"Your edit was overwritten"` with deep link to P15

**`balance:refreshed`**
- Room: `user:{userId}`
- Sent when any balance for this user changes (expense, settlement, member change)
- Payload:
```json
{
  "total_owed_to_user": 14250,
  "total_user_owes": 5000,
  "net_balance": 9250,
  "currency": "USD",
  "updated_at": "ISO-8601"
}
```
- Client action: replace Dashboard hero card values (with count-up animation if delta > 0)

---

### 3.8 System Events

**`auth_error`**
- Emitted by server to the socket on connection or mid-session token failure
- Payload: `{ "code": "TOKEN_EXPIRED" | "TOKEN_INVALID" | "ACCOUNT_DELETED" }`
- Client action:
  - `TOKEN_EXPIRED` → trigger silent refresh (same as Dio interceptor) → reconnect
  - `TOKEN_INVALID` → clear cookies → navigate to Login
  - `ACCOUNT_DELETED` → clear cookies → navigate to Login + toast

**`force_update`**
- Room: `user:{userId}` (or broadcast to all)
- Payload: `{ "min_version": "2.1.0", "current_version": "1.9.2" }`
- Client action: show FS01 force update screen immediately, block all navigation

---

## 4. CLIENT BEHAVIOR RULES

1. **All socket events are idempotent on the client.** Receiving `expense:created` for an expense already in local state (by ID) → update in place, do not duplicate.
2. **Full objects in payloads, not diffs.** The server always sends the complete updated object. Clients replace their local copy entirely — no partial merge logic needed.
3. **Socket events do NOT replace REST API calls for initial data load.** On screen open, always fetch via REST. Socket only handles incremental updates.
4. **Disconnect during events:** If socket disconnects mid-operation, the `sync_request` with `last_event_id` on reconnect ensures no events are missed.
5. **Room subscription after group join:** Server adds socket to `group:{groupId}` room immediately on join — client starts receiving group events without reconnecting.

---

## 5. SERVER EMIT PATTERNS

| Trigger | Server Action |
|---|---|
| Expense created | Emit `expense:created` to `group:{groupId}`; emit `balance:refreshed` to each affected member's personal room |
| Expense deleted | Emit `expense:deleted` to `group:{groupId}`; emit `balance:refreshed` to each affected member |
| Settlement confirmed | Emit `settlement:created` to group room + both user rooms; emit `balance:refreshed` to payer + payee |
| Member joins group | `socket.join('group:{groupId}')` server-side; emit `group:member_joined` to group room |
| Member leaves/removed | `socket.leave(...)` server-side; emit `group:member_left/removed` to group room |
| Edit conflict detected | Emit `expense:edit_conflict` to losing user's personal room only |
| Any mutation | Emit `notification:new` to recipient's personal room |
