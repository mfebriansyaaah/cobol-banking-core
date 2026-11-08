// Driver for tests/integration/provider_fallback.sh (PR-088): runs one chaos
// scenario against the fake provider owned by the shell harness and prints a
// single machine-readable result line. Fresh process per scenario, so circuit
// breakers never leak between scenarios. Usage:
//   FAKE=http://127.0.0.1:PORT TELEGRAM_API_BASE=$FAKE/telegram ... node driver.mjs <scenario> $FAKE
import { sendTelegramOtp } from '../../middleware/services/integrations/phone/telegram.js';
import { sendFreeSms } from '../../middleware/services/integrations/phone/free_sms.js';
import { createPhoneProvider, sendOtpWithFallback } from '../../middleware/services/integrations/phone.js';
import { validateNikRemote } from '../../middleware/services/integrations/identity/nusakit.js';

const [scenario, fake] = process.argv.slice(2);
const NIK = '3171010101900001';

async function ctl(service, mode) {
  const res = await fetch(`${fake}/__control`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ service, mode }),
  });
  if (!res.ok) throw new Error(`control failed for ${service}=${mode}`);
}

async function journal(service) {
  const res = await fetch(`${fake}/__calls?service=${service}`);
  return res.json();
}

const out = (pairs) => console.log(`SCENARIO=${scenario} ${pairs}`);

switch (scenario) {
  case 'tg-ok': {
    await ctl('telegram', 'ok');
    const ok = await sendTelegramOtp(
      { chatId: 'chat-1', text: 'hi', idempotencyKey: 'k1' },
      { timeoutMs: 1000 },
    );
    const j = await journal('telegram');
    out(`ok=${ok} calls=${j.count} idem=${j.requests[0]?.idempotencyKey === 'k1' ? 1 : 0}`);
    break;
  }
  case 'tg-fallback': {
    await ctl('telegram', 'http500');
    await ctl('sms', 'ok');
    const tgBefore = (await journal('telegram')).count;
    const smsBefore = (await journal('sms')).count;
    const primary = createPhoneProvider('telegram');
    const secondary = createPhoneProvider('free_sms');
    const ok = await sendOtpWithFallback(
      primary,
      secondary,
      { chatId: 'chat-1', code: '123456', to: '08123456789' },
    );
    const tg = (await journal('telegram')).count - tgBefore;
    const sms = (await journal('sms')).count - smsBefore;
    out(`ok=${ok} tg_calls=${tg} sms_calls=${sms}`);
    break;
  }
  case 'sms-400': {
    await ctl('sms', 'http400');
    const before = (await journal('sms')).count;
    let err = '';
    try {
      await sendFreeSms({ to: '+6281', text: 'hi' }, { timeoutMs: 1000 });
    } catch (e) {
      err = e.message;
    }
    const calls = (await journal('sms')).count - before;
    out(`err=${/HTTP 400/.test(err) ? 1 : 0} calls=${calls}`);
    break;
  }
  case 'nik-timeout': {
    await ctl('nik', 'timeout');
    const r = await validateNikRemote({ nik: NIK, consent: true }, { timeoutMs: 300 });
    out(`valid=${r.valid ? 1 : 0} fallback=${/fallback/.test(r.remote) ? 1 : 0}`);
    break;
  }
  case 'nik-malformed': {
    await ctl('nik', 'malformed');
    const r = await validateNikRemote({ nik: NIK, consent: true }, { timeoutMs: 1000 });
    out(`valid=${r.valid ? 1 : 0} fallback=${/fallback/.test(r.remote) ? 1 : 0}`);
    break;
  }
  case 'nik-down': {
    // The shell killed the fake before this scenario: connection refused must
    // still resolve to the local result (the user never hangs).
    const r = await validateNikRemote({ nik: NIK, consent: true }, { timeoutMs: 500 });
    out(`valid=${r.valid ? 1 : 0} fallback=${/fallback/.test(r.remote) ? 1 : 0}`);
    break;
  }
  default:
    console.log(`SCENARIO=${scenario} err=unknown-scenario`);
    process.exitCode = 1;
}
