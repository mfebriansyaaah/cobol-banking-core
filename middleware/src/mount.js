// Domain router split (PR-054): group ALL_ROUTES by first path segment and
// mount one sub-router per domain at '/' (no path prefix: stripping prefixes
// would rewrite req.route.path and silently change metrics labels and the
// route templates the observability tests lock). Mount order is first-seen
// segment order; within a mount the committed route order is kept, so
// matching is identical to the flat table by construction (segments are
// disjoint — no cross-segment shadowing is possible; route-order proves it).
export function groupRoutes(routes) {
  const groups = new Map();
  for (const route of routes) {
    const seg = String(route.path || '').split('/')[1] || '/';
    if (!groups.has(seg)) groups.set(seg, []);
    groups.get(seg).push(route);
  }
  return [...groups.entries()].map(([segment, groupRoutes]) => ({ segment, routes: groupRoutes }));
}
