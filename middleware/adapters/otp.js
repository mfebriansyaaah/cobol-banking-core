// Canonical OTP delivery adapter (ADR-0006, Option A).
// Owner: middleware/adapters. COBOL issues hashed challenges and returns the
// plaintext code once; this adapter delivers it out of band (email provider
// or verified linked chat) and reports only whether delivery succeeded.
// The code never reaches HTTP responses. Delivery failures never un-issue.
// middleware/src/otpService.js re-exports this module for backward compat.
import { createHash } from 'node:crypto';
import { invoke } from '../core-client/invoker.js';
import { PATTERNS, check } from '../src/validation.js';
import { getProviders } from '../services/integrations/index.js';
import { sendOtpWithFallback } from '../services/integrations/phone.js';
import { normalizeIdPhone } from '../services/integrations/phone/normalize.js';
import { assertQuota, recordUse } from '../services/integrations/quota.js';
import { recordFallback } from '../services/integrations/resilience.js';

function useQuota(kind) {
  return kind !== 'mock' && kind !== 'log';
}

export async function lookupChat(email, actor) {
  const raw = await invoke('OTP_CHAT', [email || '', '', '', actor || '']);
  if (!String(raw).startsWith('SUCCESS|CHAT|')) return null;
  const parts = String(raw).split('|');
  const chatId = parts[2] || '';
  const phoneHash = parts[3] || '';
  if (!chatId || !phoneHash) return null;
  return { chatId, phoneHash };
}

async function deliverEmail({ email, purpose, code }) {
  const providers = getProviders();
  const kind = (providers.email && providers.email.kind) || 'log';
  if (useQuota(kind)) assertQuota(kind);
  const ok = await providers.email.sendVerification({ to: email, purpose, code });
  if (useQuota(kind) && ok) recordUse(kind);
  return !!ok;
}

async function deliverPhone({ code, chatId = null, phone = null, phoneHash = null }) {
  const providers = getProviders();
  const primary = providers.phone;
  const kind = (primary && primary.kind) || 'mock';
  if (useQuota(kind)) assertQuota(kind);
  if (kind === 'free_sms') {
    // Raw numbers are never stored: hash the supplied candidate and send
    // only on equality with the verified stored hash.
    if (!phone || !phoneHash) {
      recordFallback({ provider: kind, reason: 'no_verified_number' });
      return false;
    }
    const normalized = normalizeIdPhone(check(String(phone), PATTERNS.PHONE, 'phone'));
    if (!normalized) return false;
    const candidate = createHash('sha256').update(normalized).digest('hex');
    if (candidate !== phoneHash) {
      recordFallback({ provider: kind, reason: 'number_mismatch' });
      return false;
    }
    await primary.sendOtp({ to: normalized, code });
    recordUse(kind);
    return true;
  }
  if (!chatId) {
    recordFallback({ provider: kind, reason: 'no_linked_chat' });
    return false;
  }
  await sendOtpWithFallback(primary, null, { chatId, code });
  if (useQuota(kind)) recordUse(kind);
  return true;
}

// Deliver an issued OTP and return the public response shape (no code).
export async function completeIssue(body, input) {
  const id = (body && body.data && body.data[1]) || '';
  const code = (body && body.data && body.data[2]) || '';
  const email = input.email || '';
  const purpose = input.purpose || '';
  const channel = input.channel || '';
  let delivered = false;
  try {
    if (!code) return { data: ['OTP_SENT'], id, delivered };
    if (channel === 'EMAIL') {
      delivered = await deliverEmail({ email, purpose: purpose || 'OTP', code });
    } else if (channel === 'PHONE') {
      const found = await lookupChat(email, input.actor || email);
      if (found) {
        delivered = await deliverPhone({ code, chatId: found.chatId, phone: input.phone, phoneHash: found.phoneHash });
      } else {
        recordFallback({ provider: 'telegram', reason: 'no_linked_chat' });
      }
    }
  } catch {
    delivered = false;
  }
  return { data: ['OTP_SENT'], id, delivered };
}
