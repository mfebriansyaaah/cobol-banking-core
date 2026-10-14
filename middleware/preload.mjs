// Test preload: keep the password KDF cheap when running the gateway suite
// directly. Production uses the compiled default (600000); the COBOL module
// reads this value from the environment.
process.env.PBKDF2_ITERATIONS ??= '100000';
