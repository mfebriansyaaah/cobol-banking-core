// KTP OCR provider: mock only. A `local` (Tesseract) backend was an explicit
// PR-084 decision requiring a native dependency that CI/dev images do not
// provide; configuring it fails fast at boot instead of at first request.
// Interface frozen: extractKtp returns extracted fields plus a confidence
// that forces manual review below threshold.
import { mockCalls } from './provider.js';

export const OCR_REVIEW_THRESHOLD = 0.85;

export function createOcrProvider(kind, { logger = null } = {}) {
  if (kind !== 'mock') {
    throw new Error(`unknown OCR provider '${kind}' (mock only; local Tesseract is undecided, see PR-084)`);
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
