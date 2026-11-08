// Infrastructure routes (previously inline in app.js): health probes and
// session endpoints with bespoke handlers (custom: true). They live in the
// route table so every static gate (auth, conflicts, dispatch, field order,
// OpenAPI, registry) sees the same surface the router serves. Registration
// order is preserved by spreading INFRA_ROUTES first in the barrel: these
// match before all domain mounts, exactly like the former inline handlers.
export const INFRA_ROUTES = [
  {
    method: 'get',
    path: '/health',
    action: 'PING',
    public: true,
    limiter: 'api',
    custom: 'health',
    fields: [],
  },
  {
    method: 'get',
    path: '/live',
    public: true,
    limiter: 'api',
    custom: 'live',
    fields: [],
  },
  {
    method: 'get',
    path: '/ready',
    action: 'PING',
    public: true,
    limiter: 'api',
    custom: 'ready',
    fields: [],
  },
  {
    method: 'get',
    path: '/metrics',
    limiter: 'api',
    permission: 'AUDIT_READ',
    custom: 'metrics',
    fields: [],
  },
  {
    method: 'post',
    path: '/auth/refresh',
    action: 'CONSUME_SESSION',
    public: true,
    limiter: 'auth',
    custom: 'refresh',
    fields: [],
  },
  {
    method: 'post',
    path: '/auth/logout',
    action: 'REVOKE_SESSION',
    public: true,
    limiter: 'auth',
    custom: 'logout',
    fields: [],
  },
  {
    method: 'post',
    path: '/auth/revoke',
    action: 'REVOKE_ACCESS_TOKEN',
    tokenIdentity: 'actor',
    limiter: 'api',
    custom: 'revoke',
    fields: [],
  },
];
