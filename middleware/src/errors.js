// Shared invocation errors, so both the file invoker and the worker pool throw
// the same classes that the router maps to HTTP.
export class InvocationTimeout extends Error {}
export class InvocationError extends Error {}
// The worker pool is at capacity: bounded backpressure, not a COBOL failure.
export class PoolSaturated extends Error {}
