import 'dotenv/config';
import { buildApp } from './app.js';
import { assertSecureConfig } from './auth.js';
import { jsonLogger } from './observability.js';

assertSecureConfig();
const port = process.env.PORT || 3000;
buildApp({ logger: jsonLogger }).listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`api-gateway listening on :${port}`);
});
