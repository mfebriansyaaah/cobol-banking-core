// Worker pool over the COBOL binary's serve mode (ADR-0010 phases 3/5). Spawns
// a few long-running `main_logic --serve` processes and dispatches requests over
// stdin/stdout, up to `pipeline` in-flight per worker (batched writes reduce IPC
// round-trips). A crashed (or timed-out) worker is rejected and replaced.
// Support only - it carries no business logic.
import { spawn } from 'node:child_process';
import { BINARY } from './binary.js';
import { InvocationTimeout, InvocationError, PoolSaturated } from './errors.js';
import { setGauge, incCounter } from './observability.js';

// Bounds on every pool knob. A malformed or absurd value used to be accepted
// silently: a non-numeric COBOL_POOL_PIPELINE became NaN, no worker ever had
// capacity, and queued requests waited forever because their timeout only
// started on dispatch. Values are validated at startup and the queue is
// bounded, so saturation is rejected instead of accumulating.
const POOL_LIMITS = { maxSize: 64, maxPipeline: 64, maxTimeoutMs: 600000, maxQueue: 100000 };

function intEnv(name, fallback, { min, max }) {
  const raw = process.env[name];
  if (raw === undefined || String(raw).trim() === '') return fallback;
  const text = String(raw).trim();
  if (!/^\d+$/.test(text)) {
    throw new Error(`${name} must be a whole number, got "${raw}"`);
  }
  const value = Number(text);
  if (value < min || value > max) {
    throw new Error(`${name} must be between ${min} and ${max}, got ${value}`);
  }
  return value;
}

/**
 * Parse and validate the worker-pool settings. `size: 0` means file mode
 * (pooling disabled); every other value is checked against POOL_LIMITS.
 * Throws on a malformed setting so a bad deployment fails fast instead of
 * hanging requests.
 */
export function poolConfig() {
  const size = intEnv('COBOL_POOL_SIZE', 0, { min: 0, max: POOL_LIMITS.maxSize });
  if (size === 0) return { size: 0 };
  const pipeline = intEnv('COBOL_POOL_PIPELINE', 1, { min: 1, max: POOL_LIMITS.maxPipeline });
  const timeoutMs = intEnv('COBOL_POOL_TIMEOUT_MS', 5000, { min: 1, max: POOL_LIMITS.maxTimeoutMs });
  const queueMax = intEnv('COBOL_POOL_QUEUE_MAX', size * pipeline * 100, { min: 1, max: POOL_LIMITS.maxQueue });
  return { size, pipeline, timeoutMs, queueMax };
}

/** Fail fast at startup when the pool settings are unusable. */
export function assertPoolConfig() {
  poolConfig();
}

class Pool {
  constructor({ size, timeoutMs, pipeline = 1, queueMax = 100, binary }) {
    this.size = size;
    this.timeoutMs = timeoutMs;
    this.pipeline = Math.max(1, pipeline);
    this.queueMax = Math.max(1, queueMax);
    this.binary = binary;
    this.workers = [];
    this.queue = [];
    this.closed = false;
    for (let i = 0; i < size; i += 1) this._addWorker();
    this._publish();
  }

  _publish() {
    const busy = this.workers.reduce((n, w) => n + w.pending.length, 0);
    setGauge('gateway_cobol_pool_workers', this.workers.length);
    setGauge('gateway_cobol_pool_busy', busy);
    setGauge('gateway_cobol_pool_queued', this.queue.length);
    setGauge('gateway_cobol_pool_queue_max', this.queueMax);
  }

  _addWorker() {
    const w = { child: null, buf: '', pending: [], alive: true };
    w.child = spawn(this.binary, ['--serve'], { stdio: ['pipe', 'pipe', 'ignore'] });
    w.child.stdout.setEncoding('utf8');
    w.child.stdout.on('data', (d) => this._onData(w, d));
    w.child.on('error', (e) => this._onGone(w, new InvocationError(e.message)));
    w.child.on('exit', () => this._onGone(w, new InvocationError('COBOL worker exited')));
    this.workers.push(w);
    return w;
  }

  _onData(w, d) {
    w.buf += d;
    let i;
    while ((i = w.buf.indexOf('\n')) >= 0) {
      const line = w.buf.slice(0, i).replace(/\s+$/, '');
      w.buf = w.buf.slice(i + 1);
      const job = w.pending.shift();
      if (job) {
        clearTimeout(job.timer);
        job.resolve(line);
      }
    }
    this._dispatch();
  }

  _onGone(w, err) {
    if (!w.alive) return;
    w.alive = false;
    for (const job of w.pending) {
      clearTimeout(job.timer);
      job.reject(err);
    }
    w.pending = [];
    this.workers = this.workers.filter((x) => x !== w);
    if (!this.closed) {
      incCounter('gateway_cobol_pool_restarts_total');
      this._addWorker();
    }
    this._dispatch();
    this._publish();
  }

  _workerWithCapacity() {
    return this.workers.find((w) => w.alive && w.pending.length < this.pipeline);
  }

  _dispatch() {
    if (this.closed) return;
    let w = this._workerWithCapacity();
    while (this.queue.length && w) {
      const room = this.pipeline - w.pending.length;
      const batch = this.queue.splice(0, room);
      this._sendBatch(w, batch);
      w = this._workerWithCapacity();
    }
    this._publish();
  }

  _sendBatch(w, jobs) {
    const payload = `${jobs.map((j) => j.line).join('\n')}\n`;
    for (const job of jobs) {
      // The job is leaving the queue: its wait budget no longer applies.
      if (job.queueTimer) {
        clearTimeout(job.queueTimer);
        job.queueTimer = null;
      }
      const timeoutMs = job.timeoutMs ?? this.timeoutMs;
      job.timer = setTimeout(() => {
        const idx = w.pending.indexOf(job);
        if (idx === -1) return;
        w.pending.splice(idx, 1);
        job.reject(new InvocationTimeout(`COBOL call exceeded ${timeoutMs}ms`));
        // The worker is likely stuck: drop it so the rest fail cleanly.
        try { w.child.kill('SIGKILL'); } catch { /* ignore */ }
      }, timeoutMs);
      w.pending.push(job);
    }
    w.child.stdin.write(payload);
  }

  invoke(action, params = [], opts = {}) {
    const line = [action, ...params].slice(0, 7).join('|');
    return new Promise((resolve, reject) => {
      if (this.closed) {
        reject(new InvocationError('COBOL pool is closed'));
        return;
      }
      if (this.queue.length >= this.queueMax) {
        incCounter('gateway_cobol_pool_rejected_total');
        reject(new PoolSaturated(`COBOL pool queue is full (${this.queueMax})`));
        return;
      }
      const job = { line, resolve, reject, timeoutMs: opts.timeoutMs };
      // Bound the wait in the queue too: a request must not hang forever
      // because every worker is saturated or stuck.
      const waitMs = job.timeoutMs ?? this.timeoutMs;
      job.queueTimer = setTimeout(() => {
        const idx = this.queue.indexOf(job);
        if (idx === -1) return;
        this.queue.splice(idx, 1);
        job.reject(new InvocationTimeout(`COBOL pool queue wait exceeded ${waitMs}ms`));
        this._publish();
      }, waitMs);
      this.queue.push(job);
      this._dispatch();
    });
  }

  stats() {
    return {
      size: this.workers.length,
      pipeline: this.pipeline,
      queueMax: this.queueMax,
      busy: this.workers.reduce((n, w) => n + w.pending.length, 0),
      queued: this.queue.length,
    };
  }

  close() {
    this.closed = true;
    // A queued job will never be dispatched now; fail it instead of hanging.
    for (const job of this.queue) {
      if (job.queueTimer) clearTimeout(job.queueTimer);
      job.reject(new InvocationError('COBOL pool is closed'));
    }
    this.queue = [];
    for (const w of this.workers) {
      try { w.child.stdin.write('QUIT\n'); } catch { /* ignore */ }
      try { w.child.kill(); } catch { /* ignore */ }
    }
    setGauge('gateway_cobol_pool_workers', 0);
    setGauge('gateway_cobol_pool_busy', 0);
    setGauge('gateway_cobol_pool_queued', 0);
    setGauge('gateway_cobol_pool_queue_max', 0);
  }
}

let POOL = null;

/** The shared pool, or null when pooling is disabled (file mode). */
export function getPool() {
  if (POOL) return POOL;
  const config = poolConfig();
  if (config.size === 0) return null;
  POOL = new Pool({ ...config, binary: BINARY });
  return POOL;
}

export function resetPool() {
  if (POOL) POOL.close();
  POOL = null;
}

export { Pool };
