// Test preload: keep the password KDF cheap when running the gateway suite
// directly. Production uses the compiled default (600000); the COBOL module
// reads this value from the environment.
process.env.PBKDF2_ITERATIONS ??= '100000';

// The gateway suite makes many auth calls across files; lift the default
// rate-limit ceilings for tests (ratelimit.test.js overrides them itself).
process.env.RATE_LIMIT_MAX ??= '100000';
process.env.RATE_LIMIT_WINDOW_MS ??= '60000';
process.env.API_RATE_LIMIT_MAX ??= '100000';
process.env.API_RATE_LIMIT_WINDOW_MS ??= '60000';
