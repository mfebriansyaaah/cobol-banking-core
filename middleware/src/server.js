import 'dotenv/config';
import { buildApp } from './app.js';
import { assertSecureConfig } from './auth.js';
import { jsonLogger, startMetricsExporter } from './observability.js';
import { resetPool } from './pool.js';

assertSecureConfig();
const port = process.env.PORT || 3000;

// Surface a production misconfiguration early: without SMTP the verification
// codes are never delivered (delivery is best-effort, so this is a warning).
if (process.env.NODE_ENV === 'production' && !process.env.SMTP_HOST) {
  jsonLogger({
    ts: new Date().toISOString(),
    level: 'warn',
    event: 'mailer_not_configured',
    message: 'SMTP_HOST is not set; verification emails will not be delivered',
  });
}

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

// Log unexpected process-level failures as structured lines so they are not
// silent. An uncaught exception leaves the process in an undefined state, so it
// is logged and the process exits non-zero.
function fatalLog(kind, err) {
  jsonLogger({
    ts: new Date().toISOString(),
    level: 'error',
    event: 'process_error',
    kind,
    message: err && err.message,
    stack: err && err.stack,
  });
}

process.on('uncaughtException', (err) => {
  fatalLog('uncaughtException', err);
  try { resetPool(); } catch { /* ignore */ }
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  fatalLog('unhandledRejection', reason instanceof Error ? reason : new Error(String(reason)));
});
