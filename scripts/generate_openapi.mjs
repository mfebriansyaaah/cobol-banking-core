import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = process.argv[2] || '.';
const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const manifestPath = path.join(ROOT, 'manifest', 'modules.json');
const outputPath = path.join(ROOT, 'docs', 'openapi.yaml');

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const routeFiles = manifest.gatewayRoutes || [];

let spec = {
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

for (const file of routeFiles) {
  const filePath = path.join(routesDir, file);
  if (!readFileSync(filePath, 'utf8')) continue;
  try {
    const content = readFileSync(filePath, 'utf8');
    const routes = content.match(/{ method: '(\w+)', path: '([^']+)', action: '(\w+)'.*?fields: \[(.*?)\]/gs);
    if (!routes) continue;
    for (const r of routes) {
      const m = r.match(/{ method: '(\w+)', path: '([^']+)', action: '(\w+)'.*?fields: \[(.*?)\]/s);
      if (!m) continue;
      const [, method, path, action] = m;
      const opKey = Object.keys(actionToOp).find((k) => action.endsWith(k));
      const op = opKey ? actionToOp[opKey] : 'list';
      const summary = `${action} — ${opMapSummary[op] || 'Execute action'}`;
      if (!spec.paths[path]) spec.paths[path] = {};
      const params = [];
      const idMatch = path.match(/:id/);
      if (idMatch) params.push({ $ref: '#/components/parameters/id' });
      if (method === 'get' && (op === 'list' || op === 'audit')) {
        if (op === 'list') {
          params.push({ $ref: '#/components/parameters/status' }, { $ref: '#/components/parameters/type' });
        }
        params.push({ $ref: '#/components/parameters/limit' }, { $ref: '#/components/parameters/offset' });
      }
      params.push({ $ref: '#/components/parameters/actor' });
      spec.paths[path][method] = {
        summary,
        tags: [file.replace('.js', '')],
        parameters: params.filter((p) => p.$ref !== '#/components/parameters/body'),
        requestBody:
          method === 'post'
            ? {
                required: true,
                content: {
                  'application/json': {
                    schema: {
                      type: 'object',
                      properties: {
                        /* TODO */
                      },
                    },
                  },
                },
              }
            : undefined,
        responses: {
          200: { description: 'Success', content: { 'text/plain': { schema: { type: 'string' } } } },
          403: {
            description: 'Forbidden',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
          },
          400: {
            description: 'Bad request',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
          },
        },
      };
    }
  } catch (e) {
    console.error('Error processing', file, e.message);
  }
}

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

writeFileSync(outputPath, require('yaml').stringify(spec));
console.log('Generated', outputPath);
