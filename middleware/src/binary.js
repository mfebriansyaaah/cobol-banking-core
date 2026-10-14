import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Absolute path to the COBOL binary. Override with COBOL_BIN.
export const BINARY =
  process.env.COBOL_BIN ||
  path.resolve(__dirname, '../../cobol/bin/main_logic');
