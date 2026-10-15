// Worker pool over the COBOL binary's serve mode (ADR-0010 phases 3/5). Spawns
// a few long-running `main_logic --serve` processes and dispatches requests over
// stdin/stdout, up to `pipeline` in-flight per worker (batched writes reduce IPC
// round-trips). A crashed (or timed-out) worker is rejected and replaced.
// Support only - it carries no business logic.
import { spawn } from 'node:child_process';
import { BINARY } from './binary.js';
import { InvocationTimeout, InvocationError } from './errors.js';
import { setGauge, incCounter } from './observability.js';

class Pool {
  constructor({ size, timeoutMs, pipeline = 1, binary }) {
    this.size = size;
    this.timeoutMs = timeoutMs;
    this.pipeline = Math.max(1, pipeline);
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
      this.queue.push({ line, resolve, reject, timeoutMs: opts.timeoutMs });
      this._dispatch();
    });
  }

  stats() {
    return {
      size: this.workers.length,
      pipeline: this.pipeline,
      busy: this.workers.reduce((n, w) => n + w.pending.length, 0),
      queued: this.queue.length,
    };
  }

  close() {
    this.closed = true;
    for (const w of this.workers) {
      try { w.child.stdin.write('QUIT\n'); } catch { /* ignore */ }
      try { w.child.kill(); } catch { /* ignore */ }
    }
  }
}

let POOL = null;

/** The shared pool, or null when pooling is disabled (file mode). */
export function getPool() {
  if (POOL) return POOL;
  const size = Number(process.env.COBOL_POOL_SIZE || 0);
  if (!Number.isFinite(size) || size <= 0) return null;
  POOL = new Pool({
    size,
    timeoutMs: Number(process.env.COBOL_POOL_TIMEOUT_MS || 5000),
    pipeline: Number(process.env.COBOL_POOL_PIPELINE || 1),
    binary: BINARY,
  });
  return POOL;
}

export function resetPool() {
  if (POOL) POOL.close();
  POOL = null;
}
