// Phone OTP provider: mock | telegram | free_sms.
// - mock: records, always succeeds (tests/development).
// - telegram: Bot API delivery to a linked chat_id (PR-082).
// - free_sms: env-configured HTTP relay (PR-082, optional).
// Interface frozen since PR-080: sendOtp({to, channel, chatId, code, text?}).
import { mockCalls, safeHealth } from './provider.js';
import { normalizeIdPhone } from './phone/normalize.js';
import { sendTelegramOtp } from './phone/telegram.js';
import { sendFreeSms } from './phone/free_sms.js';

export { normalizeIdPhone };

export function createPhoneProvider(kind, { logger = null } = {}) {
  if (!['mock', 'telegram', 'free_sms'].includes(kind)) {
    throw new Error(`unknown phone provider '${kind}' (mock|telegram|free_sms)`);
  }
  if (kind === 'mock') {
    const mock = mockCalls();
    return {
      kind,
      calls: mock.calls,
      async sendOtp({ to, channel = 'sms' }) {
        const event = { event: 'phone_otp', to: normalizeIdPhone(to) ?? to, channel };
        if (logger) logger(event);
        return mock.record(event);
      },
      async health() {
        return { ok: true, provider: 'mock', detail: null };
      },
    };
  }
  if (kind === 'telegram') {
    return {
      kind,
      async sendOtp({ chatId, code, text, logger: callLogger = null }) {
        const body = text ?? `Your verification code is ${code}`;
        const done = await sendTelegramOtp({ chatId, text: body });
        (callLogger ?? logger)?.({ event: 'phone_otp', channel: 'telegram', chatId });
        return done;
      },
      async health() {
        return safeHealth(async () => {
          if (!process.env.TELEGRAM_BOT_TOKEN) throw new Error('TELEGRAM_BOT_TOKEN missing');
          return { configured: true };
        }, kind);
      },
    };
  }
  return {
    kind: 'free_sms',
    async sendOtp({ to, code, text }) {
      const target = normalizeIdPhone(to);
      if (!target) throw new Error(`unparseable phone number: ${JSON.stringify(to)}`);
      return sendFreeSms({ to: target, text: text ?? `Your verification code is ${code}` });
    },
    async health() {
      return safeHealth(async () => {
        if (!process.env.FREE_SMS_ENDPOINT || !process.env.FREE_SMS_API_KEY) {
          throw new Error('FREE_SMS_ENDPOINT/FREE_SMS_API_KEY missing');
        }
        return { configured: true };
      }, kind);
    },
  };
}
