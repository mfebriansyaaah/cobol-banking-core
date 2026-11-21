// Response envelope v1 (arch9 WP-14): legacy paths keep their exact shape
// (`{data:[...]}` or mapper output); every route is ALSO served under the
// `/v1` alias, where success and failure share one envelope:
//
//   success: { data: <payload>, meta: { requestId, ...page }, error: null }
//   failure: { data: null, meta: { requestId }, error: { code, detail } }
//
// `data` for a paginated v1 list is the items array; `meta` carries
// requestId plus total/limit/offset. Nothing here is business logic: shaping
// stays in responseMappers.js, transport stays in app.js.

export function ok(data, meta = {}) {
  return { data, meta, error: null };
}

export function fail(code, detail = null, meta = {}) {
  return { data: null, meta, error: { code, detail } };
}

// True when the request arrived via the /v1 alias mount. Mounted routers
// set baseUrl to '/v1'; the path-prefix check covers direct app use.
export function isV1(req) {
  const base = String((req && req.baseUrl) || '');
  if (base === '/v1' || base.startsWith('/v1/')) return true;
  return String((req && req.path) || '').startsWith('/v1/');
}

function isPagedBody(body) {
  return body && typeof body === 'object' && Array.isArray(body.data) && body.meta && typeof body.meta === 'object';
}

// Envelope v1 (arch9 WP-14): legacy paths keep their exact shape; the /v1
// alias wraps every response. Paginated v1 lists (route.pagination + a mapper
// returning {data, meta}) surface items as data and page info in meta.
export function envelopeBody(req, route, status, body) {
  const meta = { requestId: (req && req.requestId) || null };
  if (status >= 400) {
    const code = (body && body.error) || 'INTERNAL';
    const detail = body ? (body.detail ?? body.field ?? null) : null;
    return fail(code, detail, meta);
  }
  if (route && route.pagination && isPagedBody(body)) {
    return ok(body.data, { ...meta, ...body.meta });
  }
  return ok(body, meta);
}

// Single response edge: legacy shape by default, envelope under /v1.
export function reply(req, res, status, body) {
  if (!isV1(req)) return res.status(status).json(body);
  return res.status(status).json(envelopeBody(req, null, status, body));
}
