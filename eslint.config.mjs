// ESLint flat config for the gateway and scripts trees (P1-6).
// - middleware/src/**/*.js: the Express gateway (transport only).
// - middleware/services/**/*.js: integration services (domain-adjacent policy).
// - middleware/workers/**/*.js: background workers (outbox, cron support).
// - middleware/test/**/*.js: node:test suites.
// - scripts/**/*.mjs plus this file: ESM tooling, gates, and unit tests.
// - Node globals only; no browser/DOM. `eslint.configs.recommended` is the
//   base; rules below are relaxed only where the codebase has an established,
//   reviewed pattern (each with a reason).
import globals from 'globals';
import eslint from '@eslint/js';

export default [
  {
    ignores: ['**/node_modules/**', 'middleware/test-results/**', 'test-results/**', 'coverage/**', 'artifacts/**'],
  },
  {
    files: ['middleware/**/*.js', 'scripts/**/*.mjs', 'eslint.config.mjs'],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module',
      globals: {
        ...globals.node,
      },
    },
    ...eslint.configs.recommended,
  },
  {
    // Gateway source must log through the injected logger, not stdout:
    // stray console output corrupts the pipe protocol responses. The few
    // remaining sites carry per-line disables with reasons.
    files: ['middleware/src/**/*.js'],
    rules: {
      'no-console': 'error',
    },
  },
  {
    // Complexity watch list (maint-02): warn, never fail. New code should
    // stay under these; the 9 current hotspots (selectFile 40,
    // assertSecureConfig 35, buildGraph/checkShards/main 33, ...) are
    // grandfathered refactoring targets, not gate failures.
    files: ['middleware/**/*.js', 'scripts/**/*.mjs'],
    rules: {
      complexity: ['warn', 25],
      'max-depth': ['warn', 6],
    },
  },
];
