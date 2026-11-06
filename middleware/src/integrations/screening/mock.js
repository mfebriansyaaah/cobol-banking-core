// Screening mock (PR-090): records, always CLEAR. Tests and development
// without fixtures. The query hash is still computed so callers can audit
// without ever logging the raw name.
import { createHash } from 'node:crypto';

export function createMockScreening({ logger = null } = {}) {
  return {
    kind: 'mock',
    async screen({ name }) {
      const event = { event: 'screening', name: 'redacted', result: 'CLEAR' };
      if (logger) logger(event);
      return {
        result: 'CLEAR',
        score: 0,
        ref: null,
        queryHash: createHash('sha256')
          .update(
            `${String(name ?? '')
              .trim()
              .toLowerCase()}|`,
          )
          .digest('hex'),
      };
    },
    async health() {
      return { ok: true, provider: 'mock', detail: null };
    },
  };
}
