// Shim (ADR-0006): canonical owner is middleware/core-client/binary.js.
// New code imports the canonical path; this file stays for backward compat.
export * from '../core-client/binary.js';
