import 'dotenv/config';
import { buildApp } from './app.js';
import { assertSecureConfig } from './auth.js';
import { jsonLogger, startMetricsExporter } from './observability.js';
import { resetPool } from './pool.js';

assertSecureConfig();
const port = process.env.PORT || 3000;
const server = buildApp({ logger: jsonLogger }).listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`api-gateway listening on :${port}`);
});

// Optionally push the counters to a remote collector.
const stopExporter = startMetricsExporter({
  url: process.env.METRICS_PUSH_URL,
  intervalMs: Number(process.env.METRICS_PUSH_INTERVAL_MS || 15000),
  logger: jsonLogger,
});

// Drain: stop accepting requests, stop the exporter, and shut down the COBOL
// worker pool before exiting.
let shuttingDown = false;
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  if (typeof stopExporter === 'function') stopExporter();
  resetPool();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
  if (signal) {
    // eslint-disable-next-line no-console
    console.log(`received ${signal}, shutting down`);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
