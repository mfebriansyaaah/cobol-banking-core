// Phone OTP provider: mock | telegram | free_sms.
// - mock: records, always succeeds (tests/development).
// - telegram: Bot API delivery to a linked chat_id (PR-082, resilient PR-086).
// - free_sms: env-configured HTTP relay (PR-082, resilient PR-086).
// Interface frozen since PR-080: sendOtp({to, channel, chatId, code, text?}).
// PR-086 adds (additive, interface unchanged): idempotencyKey passthrough
// and sendOtpWithFallback (telegram -> free_sms -> manual-review hint).
import { mockCalls, safeHealth } from './provider.js';
import { normalizeIdPhone } from './phone/normalize.js';
import { sendTelegramOtp } from './phone/telegram.js';
import { sendFreeSms } from './phone/free_sms.js';
import { recordFallback } from './resilience.js';

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
      async sendOtp({ chatId, code, text, idempotencyKey = null, logger: callLogger = null }) {
        const body = text ?? `Your verification code is ${code}`;
        const done = await sendTelegramOtp({ chatId, text: body, idempotencyKey });
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
    async sendOtp({ to, code, text, idempotencyKey = null }) {
      const target = normalizeIdPhone(to);
      if (!target) throw new Error(`unparseable phone number: ${JSON.stringify(to)}`);
      return sendFreeSms({ to: target, text: text ?? `Your verification code is ${code}`, idempotencyKey });
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

// Fallback chain (PR-086): try primary.sendOtp, on failure record a fallback
// metric and try the secondary. When both fail, throw a named error pointing
// at manual review (the caller queues MANUAL_REVIEW, never hangs the user).
// Providers are injectable so chaos tests run without network.
export async function sendOtpWithFallback(
  primary,
  secondary,
  args,
  { logger = null } = {},
) {
  try {
    return await primary.sendOtp(args);
  } catch (primaryErr) {
    recordFallback({ provider: primary?.kind ?? 'unknown', reason: secondary?.kind ?? 'manual_review' });
    if (logger) logger({ event: 'integration_fallback', from: primary?.kind, to: secondary?.kind });
    if (!secondary) {
      throw new Error(
        `phone delivery failed (${String((primaryErr && primaryErr.message) || primaryErr)}); queue manual review`,
        { cause: primaryErr },
      );
    }
    try {
      return await secondary.sendOtp(args);
    } catch (secondaryErr) {
      throw new Error(
        `phone delivery failed (primary: ${String((primaryErr && primaryErr.message) || primaryErr)}; ` +
          `fallback: ${String((secondaryErr && secondaryErr.message) || secondaryErr)}); queue manual review`,
        { cause: secondaryErr },
      );
    }
  }
}
