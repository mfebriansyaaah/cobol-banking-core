// Worker pool over the COBOL binary's serve mode (ADR-0010 phase 3). Spawns a
// few long-running `main_logic --serve` processes and dispatches requests over
// stdin/stdout, one in-flight per worker. A crashed (or timed-out) worker is
// rejected and replaced. Support only - it carries no business logic.
import { spawn } from 'node:child_process';
import { BINARY } from './binary.js';
import { InvocationTimeout, InvocationError } from './errors.js';
import { setGauge } from './observability.js';

class Pool {
  constructor({ size, timeoutMs, binary }) {
    this.size = size;
    this.timeoutMs = timeoutMs;
    this.binary = binary;
    this.workers = [];
    this.queue = [];
    this.closed = false;
    for (let i = 0; i < size; i += 1) this._addWorker();
    this._publish();
  }

  _publish() {
    setGauge('gateway_cobol_pool_workers', this.workers.length);
    setGauge('gateway_cobol_pool_busy', this.workers.filter((w) => w.current).length);
    setGauge('gateway_cobol_pool_queued', this.queue.length);
  }

  _addWorker() {
    const w = { child: null, buf: '', current: null, timer: null, alive: true };
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
      const cur = w.current;
      if (cur) {
        clearTimeout(w.timer);
        w.current = null;
        cur.resolve(line);
        this._dispatch();
      }
    }
  }

  _onGone(w, err) {
    if (!w.alive) return;
    w.alive = false;
    if (w.current) {
      clearTimeout(w.timer);
      const cur = w.current;
      w.current = null;
      cur.reject(err);
    }
    this.workers = this.workers.filter((x) => x !== w);
    if (!this.closed) this._addWorker();
    this._dispatch();
    this._publish();
  }

  _idleWorker() {
    return this.workers.find((w) => w.alive && !w.current);
  }

  _dispatch() {
    if (this.closed) return;
    let w = this._idleWorker();
    while (this.queue.length && w) {
      this._send(w, this.queue.shift());
      w = this._idleWorker();
    }
    this._publish();
  }

  _send(w, job) {
    const timeoutMs = job.timeoutMs ?? this.timeoutMs;
    w.current = job;
    w.timer = setTimeout(() => {
      if (w.current !== job) return;
      w.current = null;
      try { w.child.kill('SIGKILL'); } catch { /* ignore */ }
      job.reject(new InvocationTimeout(`COBOL call exceeded ${timeoutMs}ms`));
    }, timeoutMs);
    w.child.stdin.write(`${job.line}\n`);
  }

  invoke(action, params = [], opts = {}) {
    const line = [action, ...params].slice(0, 5).join('|');
    return new Promise((resolve, reject) => {
      this.queue.push({ line, resolve, reject, timeoutMs: opts.timeoutMs });
      this._dispatch();
    });
  }

  stats() {
    return {
      size: this.workers.length,
      busy: this.workers.filter((w) => w.current).length,
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
    binary: BINARY,
  });
  return POOL;
}

export function resetPool() {
  if (POOL) POOL.close();
  POOL = null;
}
