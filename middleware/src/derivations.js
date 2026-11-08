// Shim (ADR-0006): canonical owner is middleware/adapters/signals.js.
// Transport calls adapters for signals; COBOL decides domain transitions.
export * from '../adapters/signals.js';
