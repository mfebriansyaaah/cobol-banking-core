// Route barrel gate (PR-052): middleware/src/routes/index.js must match the
// renderer byte-for-byte (every export imported once, spread once, in the
// committed order). Regen with --write after review.
import './render_route_barrel.mjs';
