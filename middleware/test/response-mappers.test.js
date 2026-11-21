import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RESPONSE_MAPPERS, splitRows, assertFieldCount } from '../src/responseMappers.js';

test('splitRows parses rows and fields', () => {
  assert.deepEqual(splitRows('a:1;b:2'), [
    ['a', '1'],
    ['b', '2'],
  ]);
  assert.deepEqual(splitRows(''), []);
  assert.deepEqual(splitRows(null), []);
});

test('splitRows rejects short rows', () => {
  assert.throws(() => splitRows('a:1;b', { min: 2, context: 'T row' }), /invalid T row/);
});

test('assertFieldCount enforces exact shape', () => {
  assert.deepEqual(assertFieldCount(['a', 'b'], 2, 'T'), ['a', 'b']);
  assert.throws(() => assertFieldCount(['a'], 2, 'T'), /expected 2 fields, got 1/);
  assert.throws(() => assertFieldCount(['a', 'b', 'c'], 2, 'T'), /expected 2 fields, got 3/);
});

test('LIST_USERS maps rows and rejects a short row', async () => {
  const body = { data: ['LIST_DONE', '1', '7:a@b.c:Ada:USER:VERIFIED'] };
  const out = await RESPONSE_MAPPERS.LIST_USERS(body);
  assert.equal(out.total, 1);
  assert.deepEqual(out.users[0], { id: '7', email: 'a@b.c', name: 'Ada', role: 'USER', status: 'VERIFIED' });
  await assert.rejects(RESPONSE_MAPPERS.LIST_USERS({ data: ['LIST_DONE', '1', '7:a@b.c'] }), /LIST_USERS row/);
});

test('CHECK_BALANCES maps rows and rejects a short row', async () => {
  const body = { data: ['BALANCES', 'USD:10.00:8.00:ACTIVE'] };
  const out = await RESPONSE_MAPPERS.CHECK_BALANCE(body);
  assert.deepEqual(out.balances, [{ currency: 'USD', balance: '10.00', available: '8.00', status: 'ACTIVE' }]);
  await assert.rejects(RESPONSE_MAPPERS.CHECK_BALANCE({ data: ['BALANCES', 'USD:10.00'] }), /CHECK_BALANCE row/);
});

test('STATEMENT keeps a colon inside the description', async () => {
  const line = '1:2026-01-01:2026-01-01:R1:TRANSFER:DEBIT:10.00:90.00:0:note: with colon';
  const body = { data: ['STATEMENT', '100.00', '90.00', 'USD', '1', line] };
  const out = await RESPONSE_MAPPERS.STATEMENT(body);
  assert.equal(out.lines[0].description, 'note: with colon');
  assert.equal(out.lines[0].reversed, false);
  await assert.rejects(
    RESPONSE_MAPPERS.STATEMENT({ data: ['STATEMENT', '0', '0', 'USD', '1', 'short'] }),
    /STATEMENT row/,
  );
});

test('GET_DISPUTE validates the case row and messages', async () => {
  const body = {
    data: ['X', '1:o@t.com:R1:S:D:OPEN:A:2026-01-01:0:2026-01-01:R', '1', 'm1:a@b.c:hi:2026-01-01'],
  };
  const out = await RESPONSE_MAPPERS.GET_DISPUTE(body);
  assert.equal(out.case.caseId, '1');
  assert.equal(out.messages[0].body, 'hi');
  await assert.rejects(RESPONSE_MAPPERS.GET_DISPUTE({ data: ['X', '1:o@t.com', '0', ''] }), /GET_DISPUTE case/);
});
