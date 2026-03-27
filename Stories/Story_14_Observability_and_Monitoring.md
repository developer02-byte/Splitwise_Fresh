# Story 14: Observability & Monitoring - Detailed Execution Plan

## 1. Core Objective & Philosophy
You cannot fix what you cannot see. Prior to production, the app must have a silent nervous system that reports exactly where errors happen, how fast endpoints respond, and what is degrading. Every error must be traceable from the Flutter client through the Fastify backend to the exact database query, linked by a single trace ID.

---

## 2. Target Persona & Motivation
- **The Developer / DevOps Engineer:** Needs to know if the `POST /api/settlements` endpoint crashed for 10 users last night so they can isolate the DB deadlock from structured logs.
- **The On-Call Responder:** Needs instant visibility into system health without SSHing into the server. A single health endpoint and structured logs must tell the story.

---

## 3. Comprehensive Step-by-Step System Behavior

### A. Flutter Crash Reporting (Firebase Crashlytics)
1. **Trigger:** A critical Dart error occurs (e.g., `NoSuchMethodError: The method 'split' was called on null`).
2. **System State - Error Capture:** Firebase Crashlytics captures the full stack trace, device model, OS version, app version, and the user's anonymized ID. All PII (email, name, financial amounts) is stripped before transmission.
3. **System State - UX:** The user sees a graceful error screen (via `ErrorWidget.builder` override) instead of a red error dump or blank screen: "Something went wrong. We've been notified." with a "Return to Dashboard" button.
4. **System State - Dashboard:** The crash appears in the Firebase Console within seconds, grouped by stack trace similarity, with affected user count and device breakdown.

### B. Flutter Error Boundaries
1. **Trigger:** A widget subtree throws during build, layout, or paint.
2. **System State - Per-Route Boundaries:** Each major route (Dashboard, Expense Detail, Groups, Settings) is wrapped in an error boundary widget. A crash in the Expense Detail screen does not take down the entire app.
3. **Action - Fallback UI:** The error boundary renders a styled fallback: error icon, friendly message, "Go Back" button, and an optional "Report Issue" link. The error is simultaneously reported to Crashlytics.

### C. Node.js Backend Structured Logging (pino)
1. **Trigger:** Any HTTP request hits the Fastify server.
2. **System State - Request Logging:** Fastify's built-in pino logger automatically logs every request with: method, URL path, status code, response time in ms, and the `trace_id`.
3. **System State - Application Logging:** Business logic uses the request-scoped logger (`request.log.info(...)`) to add contextual entries: user actions, database operations, validation failures.
4. **System State - Error Logging:** Unhandled exceptions and explicit error catches log the full error object with stack trace, trace ID, user ID (anonymized), and request context.

### D. Trace ID Propagation
1. **Trigger:** A new HTTP request arrives at the Fastify server.
2. **System State - Generation:** A `preHandler` hook generates a UUID v4 `trace_id` (or uses one from the `X-Trace-Id` request header if the client sent it).
3. **System State - Propagation:** The trace ID is attached to the request object, included in all log entries for that request, passed to all downstream service calls, and returned in the response as `X-Trace-Id` header.
4. **System State - Client Binding:** The Flutter client stores the `X-Trace-Id` from responses. If an error occurs, Crashlytics custom keys include the trace ID, allowing backend log correlation.

### E. Health Check Endpoint
1. **Trigger:** Monitoring system (or load balancer) calls `GET /api/health` every 30 seconds.
2. **System State - Checks Performed:** The endpoint tests PostgreSQL connectivity (simple query), Redis connectivity (PING), and reports server uptime.
3. **System State - Response:** Returns `200 OK` with component status, or `503 Service Unavailable` if any critical dependency is down.

---

## 4. UI/UX Component Specifications

### `GlobalErrorBoundary`
- Wraps the entire `MaterialApp` as the outermost error handler.
- Captures errors that escape per-route boundaries.
- Renders a full-screen branded error page with the app logo, "Something unexpected happened" message, and "Restart App" button.

### `RouteErrorBoundary`
- A reusable widget wrapping each route's content.
- On error, replaces only the route content (not the navigation shell) with a styled error card.
- Includes a "Go Back" button (calls `Navigator.pop`) and "Try Again" button (rebuilds the widget).
- Logs the error to Crashlytics with the route name as context.

```dart
// lib/widgets/route_error_boundary.dart
class RouteErrorBoundary extends StatefulWidget {
  final Widget child;
  final String routeName;

  const RouteErrorBoundary({
    required this.child,
    required this.routeName,
    super.key,
  });

  @override
  State<RouteErrorBoundary> createState() => _RouteErrorBoundaryState();
}

class _RouteErrorBoundaryState extends State<RouteErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return ErrorFallbackScreen(
        routeName: widget.routeName,
        onRetry: () => setState(() => _hasError = false),
      );
    }
    return widget.child;
  }

  @override
  void didCatch(Object error, StackTrace stackTrace) {
    FirebaseCrashlytics.instance.recordError(
      error, stackTrace,
      reason: 'RouteErrorBoundary: ${widget.routeName}',
    );
    setState(() => _hasError = true);
  }
}
```

### `ErrorFallbackScreen`
- Centered layout: warning icon (amber), "Oops, something went wrong" heading, subtext "We've been notified and are looking into it", two buttons: "Go Back" and "Try Again".
- Matches the app's design system (colors, typography, spacing).

---

## 5. Technical Architecture

### Flutter Client Setup

#### Firebase Crashlytics Initialization
```dart
// lib/main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Pass all uncaught Flutter errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass uncaught async errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Custom error widget for release mode
  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const MaterialErrorScreen(); // Custom styled error widget
    };
  }

  // Set user identifier (anonymized) for crash grouping
  // Called after login:
  // FirebaseCrashlytics.instance.setUserIdentifier(userId);

  // Attach trace_id from last API call as custom key
  // FirebaseCrashlytics.instance.setCustomKey('last_trace_id', traceId);

  runApp(const SplitWiseApp());
}
```

#### Trace ID Client Integration
```dart
// lib/services/api_client.dart
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Generate client-side trace ID if not present
        options.headers['X-Trace-Id'] ??= const Uuid().v4();
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Store server trace ID for crash reporting correlation
        final traceId = response.headers.value('X-Trace-Id');
        if (traceId != null) {
          FirebaseCrashlytics.instance.setCustomKey('last_trace_id', traceId);
        }
        handler.next(response);
      },
      onError: (error, handler) {
        final traceId = error.response?.headers.value('X-Trace-Id');
        FirebaseCrashlytics.instance.log(
          'API Error: ${error.requestOptions.method} ${error.requestOptions.path} '
          'status=${error.response?.statusCode} trace_id=$traceId',
        );
        handler.next(error);
      },
    ));
  }
}
```

### Node.js Fastify Backend

#### Structured Logging with pino
```javascript
// src/app.js
const fastify = require('fastify')({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    // Structured JSON output (pino default)
    serializers: {
      req(request) {
        return {
          method: request.method,
          url: request.url,
          hostname: request.hostname,
          trace_id: request.traceId,
        };
      },
      res(reply) {
        return {
          statusCode: reply.statusCode,
        };
      },
    },
    // Redact sensitive fields from all log output
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.body.password',
        'req.body.token',
        'req.body.id_token',
        'req.body.identity_token',
        'req.body.credit_card',
      ],
      censor: '[REDACTED]',
    },
  },
});
```

#### Trace ID Middleware
```javascript
// src/plugins/trace-id.js
const fp = require('fastify-plugin');
const { v4: uuidv4 } = require('uuid');

async function traceIdPlugin(fastify) {
  fastify.addHook('onRequest', async (request, reply) => {
    // Use client-provided trace ID or generate one
    request.traceId = request.headers['x-trace-id'] || uuidv4();

    // Bind trace ID to the request logger for all subsequent log calls
    request.log = request.log.child({ trace_id: request.traceId });

    // Return trace ID in response headers
    reply.header('X-Trace-Id', request.traceId);
  });
}

module.exports = fp(traceIdPlugin);
```

#### Request Duration Logging
```javascript
// src/plugins/request-logger.js
const fp = require('fastify-plugin');

async function requestLoggerPlugin(fastify) {
  fastify.addHook('onResponse', async (request, reply) => {
    request.log.info({
      method: request.method,
      path: request.url,
      status_code: reply.statusCode,
      duration_ms: Math.round(reply.elapsedTime),
      user_id: request.user?.id || null,
      trace_id: request.traceId,
    }, 'request completed');
  });
}

module.exports = fp(requestLoggerPlugin);
```

#### Health Check Endpoint
```javascript
// src/routes/health.js
async function healthRoutes(fastify) {
  fastify.get('/api/health', async (request, reply) => {
    const checks = {
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      checks: {},
    };

    // PostgreSQL connectivity
    try {
      await fastify.prisma.$queryRaw`SELECT 1`;
      checks.checks.database = { status: 'ok' };
    } catch (error) {
      checks.checks.database = { status: 'error', message: error.message };
      checks.status = 'degraded';
    }

    // Redis connectivity
    try {
      await fastify.redis.ping();
      checks.checks.redis = { status: 'ok' };
    } catch (error) {
      checks.checks.redis = { status: 'error', message: error.message };
      checks.status = 'degraded';
    }

    // Socket.io connection count
    checks.checks.websockets = {
      status: 'ok',
      active_connections: fastify.io?.engine?.clientsCount || 0,
    };

    const statusCode = checks.status === 'ok' ? 200 : 503;
    return reply.code(statusCode).send(checks);
  });
}

module.exports = healthRoutes;
```

**Health check response example:**
```json
{
  "status": "ok",
  "uptime": 86432.5,
  "timestamp": "2026-03-25T10:30:00.000Z",
  "checks": {
    "database": { "status": "ok" },
    "redis": { "status": "ok" },
    "websockets": { "status": "ok", "active_connections": 142 }
  }
}
```

### Performance Monitoring

#### API Response Time Tracking
```javascript
// src/plugins/metrics.js
const fp = require('fastify-plugin');

async function metricsPlugin(fastify) {
  // In-memory metrics (export to Prometheus later)
  const metrics = {
    requestCount: 0,
    requestDurations: [],   // rolling window
    dbQueryDurations: [],
    errorCount: 0,
  };

  fastify.addHook('onResponse', async (request, reply) => {
    metrics.requestCount++;
    metrics.requestDurations.push({
      path: request.routeOptions?.url || request.url,
      method: request.method,
      duration_ms: Math.round(reply.elapsedTime),
      timestamp: Date.now(),
    });

    if (reply.statusCode >= 500) {
      metrics.errorCount++;
    }

    // Keep only last 1000 entries in memory
    if (metrics.requestDurations.length > 1000) {
      metrics.requestDurations = metrics.requestDurations.slice(-1000);
    }
  });

  // Expose metrics endpoint for Prometheus scraping
  fastify.get('/api/metrics', async () => {
    const durations = metrics.requestDurations;
    const avg = durations.length > 0
      ? durations.reduce((sum, d) => sum + d.duration_ms, 0) / durations.length
      : 0;

    return {
      total_requests: metrics.requestCount,
      total_errors: metrics.errorCount,
      avg_response_time_ms: Math.round(avg),
      active_websockets: fastify.io?.engine?.clientsCount || 0,
    };
  });

  fastify.decorate('metrics', metrics);
}

module.exports = fp(metricsPlugin);
```

#### Database Query Duration Tracking (Prisma Middleware)
```javascript
// src/plugins/prisma.js
fastify.prisma.$use(async (params, next) => {
  const start = Date.now();
  const result = await next(params);
  const duration = Date.now() - start;

  fastify.log.info({
    prisma_model: params.model,
    prisma_action: params.action,
    duration_ms: duration,
  }, 'prisma query');

  // Alert on slow queries (> 500ms)
  if (duration > 500) {
    fastify.log.warn({
      prisma_model: params.model,
      prisma_action: params.action,
      duration_ms: duration,
    }, 'slow query detected');
  }

  return result;
});
```

### Alerting Strategy

**Phase 1 (Current - Log-Based):**
- Structured JSON logs to stdout. Docker captures logs automatically.
- Log rotation via `logrotate` on Hetzner VPS (daily rotation, 30-day retention, gzip compression).
- Simple log scanning script (cron job) that checks for `level: "error"` count exceeding threshold and sends email/webhook alert.

**Phase 2 (Future - Grafana/Prometheus on Hetzner):**
- Prometheus scrapes `/api/metrics` endpoint every 15s.
- Grafana dashboards for: request rate, error rate, P95 response time, DB query latency, WebSocket connection count.
- Alertmanager rules for: error rate > 5%, P95 > 2s, health check failing, disk usage > 80%.

### Log Storage on Hetzner

```bash
# /etc/logrotate.d/splitwise
/var/log/splitwise/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

Logs flow: Fastify pino (structured JSON to stdout) -> Docker log driver -> `/var/log/splitwise/app.log` -> logrotate handles rotation and compression.

---

## 6. Edge Cases & Error Handling

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **PII data leakage** | A user submits a password or sensitive token that triggers an error log. | pino `redact` configuration strips `password`, `token`, `id_token`, `identity_token`, `credit_card`, `authorization`, and `cookie` fields from all log output before it leaves the process. |
| **Crashlytics SDK failure** | Firebase servers are unreachable or SDK throws internally. | Crashlytics operates fire-and-forget. SDK failures are caught silently. The app continues functioning without any user-facing impact. Observability dependencies must never block the main thread. |
| **Log volume spike** | A bug causes thousands of errors per minute, filling disk. | Log rotation with size limit (100MB per file). Rate-limiting on error logs: after 100 identical errors in 1 minute, log a summary instead of individual entries. |
| **Trace ID missing** | Client does not send `X-Trace-Id` header. | Server generates one automatically. All logs for that request still correlate correctly. |
| **Health check flapping** | Database connection briefly drops and recovers. | Health endpoint returns `503` during the outage. Load balancer (Hetzner LB in later phase) stops routing traffic to the instance. On recovery, returns `200` and traffic resumes. No manual intervention needed. |
| **Slow query cascade** | One slow DB query blocks others, degrading overall performance. | Prisma middleware logs all queries over 500ms as warnings. Patterns of slow queries surface in logs for debugging. Connection pool timeouts prevent total lockup. |

---

## 7. QA Acceptance Criteria

- [ ] Firebase Crashlytics captures unhandled Dart exceptions with full stack traces on iOS and Android.
- [ ] Crashlytics reports include device model, OS version, app version, and anonymized user ID.
- [ ] No PII (passwords, tokens, financial data) appears in any Crashlytics report or server log.
- [ ] `ErrorWidget.builder` override displays a styled error screen in release mode (not the default red error).
- [ ] Per-route `RouteErrorBoundary` contains crashes to the affected route without crashing the entire app.
- [ ] Every Fastify request produces a structured JSON log entry with: method, path, status_code, duration_ms, trace_id.
- [ ] `X-Trace-Id` header is present on every API response.
- [ ] Trace ID from the Flutter client propagates through to backend logs, enabling end-to-end request tracing.
- [ ] `GET /api/health` returns `200` with database and Redis status when all services are healthy.
- [ ] `GET /api/health` returns `503` when PostgreSQL or Redis is unreachable.
- [ ] Prisma middleware logs query durations and warns on queries exceeding 500ms.
- [ ] Logs are written to stdout as structured JSON and captured by Docker on the Hetzner VPS.
- [ ] Logrotate is configured for daily rotation with 30-day retention.
- [ ] Crashlytics SDK failure does not crash the app or degrade user experience.
- [ ] The `/api/metrics` endpoint returns request count, error count, average response time, and WebSocket connection count.
