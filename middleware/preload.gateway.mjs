// Test preload for the gateway integration suites (test:gateway): route
// requests through the persistent COBOL worker pool instead of spawning one
// process per call. Mirrors the values pool.test.js uses (SIZE=2,
// PIPELINE=4). Scoped to test:gateway only: pool-config.test.js assumes file
// mode when COBOL_POOL_SIZE is unset, so this must not leak into preload.mjs.
import './preload.mjs';

process.env.COBOL_POOL_SIZE ??= '2';
process.env.COBOL_POOL_PIPELINE ??= '4';
