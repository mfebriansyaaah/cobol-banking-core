// OpenAPI generator: docs/openapi.yaml rendered from contracts/actions.yaml
// (the registry is the source of truth; routes feed the registry via
// build_contract.mjs). No yaml dependency — minimal deterministic emitter
// below. Usage: node scripts/generate_openapi.mjs [root] [--write];
// check mode (default) fails on drift.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { loadContract } from './lib/contract.mjs';

const args = process.argv.slice(2);
const ROOT = args.find((a) => !a.startsWith('--')) || '.';
const WRITE = args.includes('--write');
const outputPath = path.join(ROOT, 'docs', 'openapi.yaml');

const opMapSummary = {
  list: 'List entities',
  create: 'Create entity',
  get: 'Get entity by ID',
  update: 'Update entity',
  delete: 'Delete/close entity',
  calc: 'Execute action',
  summary: 'Get summary statistics',
  audit: 'List audit trail',
  validate: 'Validate input',
};

const actionToOp = {
  LIST: 'list',
  CREATE: 'create',
  GET: 'get',
  UPDATE: 'update',
  DELETE: 'delete',
  CLOSE: 'delete',
  CALC: 'calc',
  ALLO: 'calc',
  SCREEN: 'calc',
  APPROVE: 'calc',
  SUBMIT: 'calc',
  SUMMARY: 'summary',
  AUDIT: 'audit',
  VALIDATE: 'validate',
};

function yamlScalar(v) {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  const s = String(v);
  if (
    s === '' ||
    /[:#[\]{},&*!|>'"%@`\n]/.test(s) ||
    /^\s|\s$/.test(s) ||
    /^(true|false|null|~|[0-9]+(\.[0-9]+)?)$/.test(s)
  ) {
    return JSON.stringify(s);
  }
  return s;
}

function toYaml(value, indent = 0) {
  const pad = '  '.repeat(indent);
  if (Array.isArray(value)) {
    if (!value.length) return '[]';
    // ADR-0006: valid block sequences. Scalars inline; objects use
    // `- key: value` on first line, subsequent keys aligned under it.
    const lines = [];
    for (const v of value) {
      if (v && typeof v === 'object') {
        const keys = Object.keys(v);
        if (!keys.length) {
          lines.push(`${pad}- {}`);
          continue;
        }
        const [first, ...rest] = keys;
        lines.push(`${pad}- ${yamlScalar(first)}:${toYaml(v[first], indent + 1).replace(/^(?!\n)/, ' ')}`);
        for (const k of rest) {
          lines.push(`${pad}  ${yamlScalar(k)}:${toYaml(v[k], indent + 1).replace(/^(?!\n)/, ' ')}`);
        }
      } else {
        lines.push(`${pad}- ${yamlScalar(v)}`);
      }
    }
    return `\n${lines.join('\n')}`;
  }
  if (value && typeof value === 'object') {
    const keys = Object.keys(value);
    if (!keys.length) return '{}';
    return `\n${keys.map((k) => `${pad}${yamlScalar(k)}:${toYaml(value[k], indent + 1).replace(/^(?!\n)/, ' ')}`).join('\n')}`;
  }
  return yamlScalar(value);
}

const spec = {
  openapi: '3.0.3',
  info: {
    title: 'COBOL Banking Core Gateway',
    version: '1.0.0',
    description:
      'REST API gateway for COBOL banking core. Each endpoint maps to a COBOL action via a pipe-delimited IPC bridge.',
  },
  servers: [{ url: 'http://localhost:3000', description: 'Local development' }],
  paths: {},
  components: {
    schemas: {
      Error: {
        type: 'object',
        properties: {
          error: { type: 'string', description: 'Error code' },
          message: { type: 'string' },
        },
      },
      Actor: { type: 'string', format: 'email', description: 'Actor email from JWT' },
      Limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
      Offset: { type: 'integer', minimum: 0, default: 0 },
    },
    parameters: {
      id: { name: 'id', in: 'path', required: true, schema: { type: 'integer' } },
      status: { name: 'status', in: 'query', schema: { type: 'string' } },
      type: { name: 'type', in: 'query', schema: { type: 'string' } },
      limit: { name: 'limit', in: 'query', schema: { $ref: '#/components/schemas/Limit' } },
      offset: { name: 'offset', in: 'query', schema: { $ref: '#/components/schemas/Offset' } },
      actor: {
        name: 'actor',
        in: 'query',
        schema: { $ref: '#/components/schemas/Actor' },
        description: 'Actor email (overrides JWT for testing)',
      },
    },
  },
};

for (const entry of [...loadContract(ROOT)].sort((a, b) => a.seq - b.seq)) {
  const { method, path: routePath, action } = entry;
  const file = entry.routeFile || '';
  const fields = entry.fields || [];
  {
    const opKey = Object.keys(actionToOp).find((k) => action.endsWith(k));
    const op = opKey ? actionToOp[opKey] : 'list';
    if (!spec.paths[routePath]) spec.paths[routePath] = {};
    const params = [];
    if (/:id/.test(routePath)) params.push({ $ref: '#/components/parameters/id' });
    if (method === 'get' && (op === 'list' || op === 'audit')) {
      if (op === 'list') {
        params.push({ $ref: '#/components/parameters/status' }, { $ref: '#/components/parameters/type' });
      }
      params.push({ $ref: '#/components/parameters/limit' }, { $ref: '#/components/parameters/offset' });
    }
    params.push({ $ref: '#/components/parameters/actor' });
    const properties = {};
    const required = [];
    // Only inline (client-sent) fields go in the body. Bare identifiers
    // (BLANK/ACTOR/ID) are positional padding or server-injected identity.
    for (const f of fields) {
      if (!f.inline || !f.name) continue;
      properties[f.name] = { type: 'string' };
      if (f.required) required.push(f.name);
    }
    const body = { type: 'object', properties };
    if (required.length) body.required = required;
    spec.paths[routePath][method] = {
      operationId: action,
      summary: `${action} — ${opMapSummary[op] || 'Execute action'}`,
      tags: [file.replace('.js', '')],
      parameters: params,
      ...(method === 'post'
        ? { requestBody: { required: true, content: { 'application/json': { schema: body } } } }
        : {}),
      responses: {
        200: { description: 'Success' },
        400: {
          description: 'Bad request',
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
        403: {
          description: 'Forbidden',
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
      },
    };
  }
}

const rendered = `# Generated by scripts/generate_openapi.mjs (do not hand-edit).\n${Object.keys(spec)
  .map((k) => `${k}:${toYaml(spec[k], 1).replace(/^(?!\n)/, ' ')}`)
  .join('\n')}\n`;

if (!WRITE) {
  const current = readFileSync(outputPath, 'utf8');
  if (current !== rendered) {
    console.error('openapi drifted: run scripts/generate_openapi.mjs --write and review the diff');
    process.exit(1);
  }
  console.log(`OK: openapi in sync (${Object.keys(spec.paths).length} paths)`);
} else {
  writeFileSync(outputPath, rendered);
  console.log(`wrote ${outputPath}: ${Object.keys(spec.paths).length} paths`);
}
