# Error Handling Contract
> Resolves Architecture Audit Issue: #15 (No global error classification system)
> Version: 1.0 | March 26, 2026

---

## 1. ERROR CLASSIFICATION SYSTEM

Every error in the system falls into exactly one category. The category determines the UI behavior.

| Category | HTTP Codes | Trigger | Flutter UI Response |
|---|---|---|---|
| **Validation** | 400, 422 | User input is invalid | Inline field-level error, no toast |
| **Auth** | 401 | Token expired or invalid | Silent refresh → retry; if refresh fails → Login screen |
| **Forbidden** | 403 | User lacks permission | Toast: `"You don't have permission to do this"` |
| **Not Found** | 404 | Resource deleted or moved | Toast: `"This [item] no longer exists"` + navigate back |
| **Conflict** | 409 | Edit conflict / duplicate | Inline error OR conflict notification (per spec) |
| **Rate Limited** | 429 | Too many requests | Contextual UI per screen (countdown on login, toast elsewhere) |
| **Server Error** | 500, 502, 503 | Backend crash or overload | Toast: `"Something went wrong. Please try again."` |
| **Network Timeout** | — | No response within 10s | Offline banner (FS03) + queue write operation locally |
| **No Connection** | — | Device offline | Offline banner (FS03) + queue write |
| **Unhandled** | Any | Unexpected JS/Dart exception | Sentry capture, toast: `"An unexpected error occurred"`, app continues |

---

## 2. SERVER ERROR RESPONSE SHAPE

All API errors follow this consistent envelope:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Payer amounts must add up to the total expense amount",
    "field": "payer_amounts",        // present for validation errors only
    "retry_after": 47,               // present for 429 only (seconds)
    "request_id": "trace-uuid"       // always present, for Sentry correlation
  }
}
```

### Error Codes (Exhaustive)
| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_FAILED` | 400 | Input validation failed |
| `INVALID_CURRENCY` | 400 | Currency code not in ISO 4217 |
| `AMOUNT_TOO_SMALL` | 400 | Amount ≤ 0 |
| `PAYER_SUM_MISMATCH` | 400 | Multi-payer amounts ≠ total |
| `TOKEN_EXPIRED` | 401 | JWT access token expired |
| `TOKEN_INVALID` | 401 | JWT signature invalid or tampered |
| `SESSION_REVOKED` | 401 | token_version mismatch |
| `REFRESH_EXPIRED` | 401 | Refresh token expired |
| `ACCOUNT_DELETED` | 401 | User account was deleted |
| `INSUFFICIENT_ROLE` | 403 | User is not admin/owner |
| `SELF_REVOKE_BLOCKED` | 403 | Cannot revoke own session |
| `CANNOT_LEAVE_WITH_DEBT` | 403 | Leave group blocked by debt |
| `DELETE_BLOCKED_BY_DEBT` | 403 | Account deletion blocked by debt |
| `NOT_GROUP_MEMBER` | 403 | User not in group |
| `EXPENSE_NOT_FOUND` | 404 | Expense deleted or never existed |
| `GROUP_NOT_FOUND` | 404 | Group deleted |
| `USER_NOT_FOUND` | 404 | User not found |
| `INVITE_EXPIRED` | 410 | Invite token expired or revoked |
| `EDIT_CONFLICT` | 409 | Last-write-wins conflict |
| `DUPLICATE_REQUEST` | 409 | Idempotency key already used |
| `ALREADY_GROUP_MEMBER` | 409 | User already in group |
| `RATE_LIMITED` | 429 | Request rate limit exceeded |
| `INTERNAL_ERROR` | 500 | Unhandled server exception |
| `EXPORT_FAILED` | 500 | Export job failed |

---

## 3. FLUTTER ERROR HANDLING ARCHITECTURE

### 3.1 Dio Error Interceptor (Global)

A single Dio interceptor handles all HTTP error responses before they reach any screen:

```
On DioException received:

1. If response.statusCode == 401:
   → Parse error.code
   → If TOKEN_EXPIRED or SESSION_REVOKED:
       → Attempt silent refresh (Auth_Contract.md §2.2)
   → If REFRESH_EXPIRED or ACCOUNT_DELETED:
       → Clear cookies, navigate to Login
   → Else: pass error through

2. If response.statusCode == 429:
   → Extract Retry-After from response header
   → Store in RateLimitProvider (Riverpod)
   → If on Login screen: drives FS02 countdown
   → Else: show toast "Rate limited. Try again in Xs"

3. If timeout (DioExceptionType.connectionTimeout, receiveTimeout):
   → Trigger offline detection
   → Show FS03 banner
   → If was a write operation: enqueue to offline_queue

4. If response.statusCode == 404:
   → Show toast: "This [item] no longer exists"
   → Call router.pop() to navigate back

5. If response.statusCode == 500:
   → Capture to Sentry with request_id from response
   → Show toast: "Something went wrong. Please try again."

6. For all others:
   → Pass the parsed error object to the calling provider
   → Provider exposes it as AsyncError state
   → Screen renders inline error UI
```

### 3.2 Per-Screen Error Display

**Validation errors (400, 422):**
- Never shown as a toast
- Always shown inline, adjacent to the offending field
- The `error.field` value from the server maps to the specific input widget
- If no `field` is provided: shown at the top of the form in a red alert banner

**Auth errors (401):**
- Handled entirely by the interceptor — screens never see a 401

**Conflict errors (409):**
- `EDIT_CONFLICT` → conflict notification (defined in Realtime_Contract.md)
- `DUPLICATE_REQUEST` → silently swallowed (the original request succeeded — idempotency worked)
- `ALREADY_GROUP_MEMBER` → shown inline on Group Preview (P17)

---

## 4. SENTRY INTEGRATION

### What Gets Captured
| Event | Sentry Level |
|---|---|
| 500 server error (with request_id) | `error` |
| Unhandled Dart exception in Flutter | `fatal` |
| DLQ job (from Jobs_Contract) | `error` |
| Conflict detected (409) | `warning` |
| Rate limit hit (429) | `info` |

### Context on Every Capture
```
user.id: "[uuid]"
user.email: "[email]"
tags.platform: "flutter_ios | flutter_android | flutter_web"
tags.app_version: "2.1.0"
extra.request_id: "[uuid from server response]"
extra.route: "/groups/abc/expenses"
```

---

## 5. GLOBAL ERROR BOUNDARY (Flutter)

Wrap the entire widget tree in a custom `ErrorBoundary` widget:

```
Behavior on uncaught Flutter error:
  1. Capture to Sentry with full stack trace
  2. Show full-screen error page:
     - Icon: warning triangle
     - Title: "Something went wrong"
     - Body: "We've been notified and are looking into it."
     - Button: "Reload App" (triggers hot restart via flutter_restart)
  3. Do NOT show raw stack traces to users (production only)
```

In debug mode: standard Flutter red screen with stack trace.

---

## 6. NETWORK DETECTION

### Connectivity Package
Use `connectivity_plus` (Flutter) to detect connectivity changes.

```
On connectivity change:
  → Connected:
    1. Hide FS03 offline banner
    2. Trigger offline_queue drain
    3. If socket was disconnected: re-connect + emit sync_request
  
  → Disconnected:
    1. Show FS03 banner: "[⚡ Offline] Changes will sync when you reconnect"
    2. Write operations go to offline_queue
    3. Read operations serve from Riverpod cache
    4. Socket connection drops automatically
```

### Server Timeout Configuration
```
Dio connectTimeout: 10 seconds
Dio receiveTimeout: 30 seconds (longer for export/upload endpoints)
```

After timeout: treat as offline — invoke offline flow, do not show generic error.
