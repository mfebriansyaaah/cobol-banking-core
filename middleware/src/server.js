import 'dotenv/config';
import { buildApp } from './app.js';

const port = process.env.PORT || 3000;
buildApp().listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`api-gateway listening on :${port}`);
});
