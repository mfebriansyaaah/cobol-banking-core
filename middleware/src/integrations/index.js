// Provider registry (PR-080): single entry point for every integration.
// Cached singletons per process (resettable for tests); factories stay pure
// and dependency-free at import time.
import { integrationConfig, assertIntegrationConfig } from './config.js';
import { createEmailProvider } from './email.js';
import { createPhoneProvider } from './phone.js';
import { createIdentityProvider } from './identity.js';
import { createOcrProvider } from './ocr.js';

export const EMAIL_PROVIDER = ['sendVerification', 'sendNotice', 'health'];
export const PHONE_PROVIDER = ['sendOtp', 'health'];
export const IDENTITY_PROVIDER = ['validateNik', 'health'];
export const OCR_PROVIDER = ['extractKtp', 'health'];

let cache = null;

export function resetProviders() {
  cache = null;
}

export function getProviders({ logger = null } = {}) {
  if (!cache) {
    const cfg = integrationConfig();
    cache = {
      config: cfg,
      email: createEmailProvider(cfg.email, { logger }),
      phone: createPhoneProvider(cfg.phone, { logger }),
      identity: createIdentityProvider(cfg.identity, { logger }),
      ocr: createOcrProvider(cfg.ocr, { logger }),
    };
  }
  return cache;
}

export { assertIntegrationConfig };
