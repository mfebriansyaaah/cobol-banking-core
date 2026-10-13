// Support-only seam for access-token validity and revocation. The default
// store is the shared database (via the COBOL core); a distributed store
// (e.g. Redis) can implement the same two methods without touching the router.
import { invoke } from './invoker.js';

export function createTokenStore() {
  return {
    // True when the token's version is current and its jti is not denylisted.
    async isActive({ email, ver, jti }) {
      const raw = await invoke('CHECK_TOKEN', [email || '', String(ver ?? ''), jti || '']);
      return raw === 'SUCCESS|TOKEN_VALID';
    },
    // Deny a single access token until it would have expired.
    async revoke({ jti, email, ttlSeconds }) {
      await invoke('REVOKE_ACCESS_TOKEN', [jti || '', email || '', String(ttlSeconds || 0)]);
    },
  };
}
