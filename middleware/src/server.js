import 'dotenv/config';
import { buildApp } from './app.js';
import { assertSecureConfig } from './auth.js';
import { jsonLogger, startMetricsExporter } from './observability.js';

assertSecureConfig();
const port = process.env.PORT || 3000;
buildApp({ logger: jsonLogger }).listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`api-gateway listening on :${port}`);
});

// Optionally push the counters to a remote collector.
startMetricsExporter({
  url: process.env.METRICS_PUSH_URL,
  intervalMs: Number(process.env.METRICS_PUSH_INTERVAL_MS || 15000),
  logger: jsonLogger,
});
