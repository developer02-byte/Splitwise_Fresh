import fp from 'fastify-plugin';
import { FastifyInstance } from 'fastify';

interface MetricEntry {
  path: string;
  method: string;
  duration_ms: number;
  timestamp: number;
}

async function metricsPlugin(fastify: FastifyInstance) {
  const metrics = {
    requestCount: 0,
    requestDurations: [] as MetricEntry[],
    errorCount: 0,
  };

  fastify.addHook('onResponse', async (request, reply) => {
    metrics.requestCount++;
    metrics.requestDurations.push({
      path: request.routeOptions?.config?.url || request.url,
      method: request.method,
      duration_ms: Math.round(reply.elapsedTime),
      timestamp: Date.now(),
    });

    if (reply.statusCode >= 500) {
      metrics.errorCount++;
    }

    if (metrics.requestDurations.length > 1000) {
      metrics.requestDurations = metrics.requestDurations.slice(-1000);
    }
    
    request.log.info({
      method: request.method,
      path: request.url,
      status_code: reply.statusCode,
      duration_ms: Math.round(reply.elapsedTime),
      user_id: (request as any).userId || null,
      trace_id: request.traceId,
    }, 'request completed');
  });

  fastify.get('/metrics', async () => {
    const durations = metrics.requestDurations;
    const avg = durations.length > 0
      ? durations.reduce((sum, d) => sum + d.duration_ms, 0) / durations.length
      : 0;

    return {
      total_requests: metrics.requestCount,
      total_errors: metrics.errorCount,
      avg_response_time_ms: Math.round(avg),
    };
  });
}

export default fp(metricsPlugin);
