import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { pingCheck, pingFail } from '../../src/integrations/ops/healthchecks.js';
import { alertTargets, sendAlert } from '../../src/integrations/ops/notify.js';

async function withEnv(vars, fn) {
  const saved = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    return await fn();
  } finally {
    for (const k of Object.keys(vars)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

test('pingCheck hits the check URL, false without id or on down', async () => {
  const hits = [];
  const server = http.createServer((req, res) => {
    hits.push(req.url);
    res.statusCode = 200;
    res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal(await pingCheck('abc', { base }), true);
  assert.deepEqual(hits, ['/abc']);
  assert.equal(await pingFail('abc', 'boom', { base }), true);
  assert.deepEqual(hits, ['/abc', '/abc/fail']);
  await new Promise((resolve) => server.close(resolve));
  assert.equal(await pingCheck('', { base }), false);
  assert.equal(await pingCheck('abc', { base, timeoutMs: 200 }), false);
});

test('sendAlert fans out without PII, survives target failure', async () => {
  const bodies = [];
  const server = http.createServer((req, res) => {
    let b = '';
    req.on('data', (c) => {
      b += c;
    });
    req.on('end', () => {
      bodies.push(b);
      res.statusCode = 200;
      res.end('{}');
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  await withEnv(
    {
      TELEGRAM_BOT_TOKEN: 'tok',
      TELEGRAM_API_BASE: base,
      ALERT_TELEGRAM_CHAT_ID: 'chat-1',
      ALERT_NTFY_TOPIC: 'ops-test',
      NTFY_SERVER: base,
    },
    async () => {
      assert.deepEqual(alertTargets().sort(), ['ntfy', 'telegram']);
      const seen = [];
      const r = await sendAlert('OUTBOX_DEAD', { id: '42', purpose: 'SIGNUP' }, { logger: (e) => seen.push(e) });
      assert.equal(r.telegram, true);
      assert.equal(r.ntfy, true);
      const blob = bodies.join('\n');
      assert.ok(!blob.includes('user@test.com'));
      assert.ok(blob.includes('OUTBOX_DEAD'));
    },
  );
  await new Promise((resolve) => server.close(resolve));
  await withEnv({ ALERT_TELEGRAM_CHAT_ID: undefined, ALERT_NTFY_TOPIC: undefined }, () => {
    assert.deepEqual(alertTargets(), []);
  });
  const r = await withEnv({ ALERT_TELEGRAM_CHAT_ID: 'x', TELEGRAM_BOT_TOKEN: 'y' }, () =>
    sendAlert('X', {}, { fetchImpl: () => Promise.reject(new Error('down')), logger: () => {} }),
  );
  assert.equal(r.telegram, false);
});
