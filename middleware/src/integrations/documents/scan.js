// ClamAV scan gate (PR-096): INSTREAM over TCP, chunked. CLEAN stores,
// INFECTED rejects, timeout/unreachable quarantines (never stores on doubt).
// Pure-net, injectable socket factory for tests; the fake speaks just enough
// of the protocol (zINSTREAM preamble, chunk frames, nENDSTREAM).
import { DEFAULT_TIMEOUT_MS } from '../resilience.js';

const CHUNK = 8192;

function writeFrame(socket, bytes) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(bytes.length, 0);
  socket.write(Buffer.concat([len, Buffer.from(bytes)]));
}

export async function scanBuffer(
  bytes,
  {
    connect = null,
    host = process.env.CLAMAV_HOST || '127.0.0.1',
    port = Number(process.env.CLAMAV_PORT || 3310),
    timeoutMs = Number(process.env.CLAMAV_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
  } = {},
) {
  return new Promise((resolve) => {
    const done = (result) => resolve(result);
    let socket;
    try {
      socket = (connect || defaultConnect())(host, port);
    } catch {
      done({ verdict: 'QUARANTINE', detail: 'scanner unreachable' });
      return;
    }
    const timer = setTimeout(() => {
      socket.destroy();
      done({ verdict: 'QUARANTINE', detail: 'scan timeout' });
    }, timeoutMs);
    let text = '';
    socket.on('data', (chunk) => {
      text += chunk.toString('utf8');
    });
    socket.on('error', () => {
      clearTimeout(timer);
      done({ verdict: 'QUARANTINE', detail: 'scanner error' });
    });
    socket.on('close', () => {
      clearTimeout(timer);
      if (/OK$/.test(text.trim())) done({ verdict: 'CLEAN' });
      else if (/FOUND$/.test(text.trim())) {
        done({ verdict: 'INFECTED', detail: text.trim().slice(0, 120) });
      } else if (!text) done({ verdict: 'QUARANTINE', detail: 'empty reply' });
      else done({ verdict: 'QUARANTINE', detail: text.trim().slice(0, 120) });
    });
    try {
      socket.write('zINSTREAM\0');
      for (let i = 0; i < bytes.length; i += CHUNK) writeFrame(socket, bytes.subarray(i, i + CHUNK));
      const end = Buffer.alloc(4);
      socket.write(end);
    } catch {
      clearTimeout(timer);
      done({ verdict: 'QUARANTINE', detail: 'write failed' });
    }
  });
}

function defaultConnect() {
  return (host, port) => {
    // Lazy import keeps unit-test graphs dependency-free.
    const { default: net } = process.getBuiltinModule('node:net');
    return net.createConnection({ host, port });
  };
}
