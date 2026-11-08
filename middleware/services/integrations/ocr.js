// KTP OCR provider (PR-080): mock | local.
// Only mock exists; local (Tesseract) is an explicit PR-084 decision with
// a native dependency. Interface frozen now: extractKtp returns extracted
// fields plus a confidence that forces manual review below threshold.
import { mockCalls, safeHealth } from './provider.js';

export const OCR_REVIEW_THRESHOLD = 0.85;

export function createOcrProvider(kind, { logger = null } = {}) {
  if (kind === 'local') {
    return {
      kind,
      async extractKtp() {
        throw new Error('local OCR not implemented yet (PR-084 decides Tesseract)');
      },
      async health() {
        return safeHealth(async () => {
          throw new Error('local OCR not implemented yet (PR-084 decides Tesseract)');
        }, 'local');
      },
    };
  }
  const mock = mockCalls();
  return {
    kind: 'mock',
    calls: mock.calls,
    async extractKtp({ imageRef }) {
      const event = { event: 'ktp_extract', imageRef, confidence: 1 };
      if (logger) logger(event);
      mock.record(event);
      return { ok: true, fields: {}, confidence: 1, needsReview: false };
    },
    async health() {
      return { ok: true, provider: 'mock', detail: null };
    },
  };
}
