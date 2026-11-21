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

const V1 = { req: { baseUrl: '/v1', path: '/x' } };

test('pageMeta reports totals and echoes paging with conventional defaults', async () => {
  const { pageMeta } = await import('../src/responseMappers.js');
  assert.deepEqual(pageMeta({ limit: '5', offset: '10' }, '42'), { total: 42, limit: 5, offset: 10 });
  assert.deepEqual(pageMeta({}, null), { total: null, limit: 20, offset: 0 });
  assert.deepEqual(pageMeta({ limit: 'abc' }, 'nope'), { total: null, limit: 20, offset: 0 });
});

test('LIST_USERS v1 returns data+meta, legacy shape untouched', async () => {
  const body = { data: ['LIST_DONE', '2', '7:a@b.c:Ada:USER:VERIFIED'] };
  const out = await RESPONSE_MAPPERS.LIST_USERS(body, { limit: '1', offset: '0' }, V1);
  assert.deepEqual(out, {
    data: [{ id: '7', email: 'a@b.c', name: 'Ada', role: 'USER', status: 'VERIFIED' }],
    meta: { total: 2, limit: 1, offset: 0 },
  });
  assert.deepEqual(await RESPONSE_MAPPERS.LIST_USERS(body, {}, {}), {
    data: ['USERS'],
    total: 2,
    users: [{ id: '7', email: 'a@b.c', name: 'Ada', role: 'USER', status: 'VERIFIED' }],
  });
});

test('STATEMENT v1 returns lines as data with the COBOL total', async () => {
  const line = '1:2026-01-01:2026-01-01:R1:TRANSFER:DEBIT:10.00:90.00:0:note';
  const out = await RESPONSE_MAPPERS.STATEMENT({ data: ['STATEMENT', '100.00', '90.00', 'USD', '7', line] }, {}, V1);
  assert.equal(out.data.length, 1);
  assert.deepEqual(out.meta, { total: 7, limit: 20, offset: 0 });
});

test('LIST_DISPUTES v1 returns cases as data', async () => {
  const out = await RESPONSE_MAPPERS.LIST_DISPUTES(
    { data: ['X', '3', '9:o@t.co:S:OPEN:2026-02-01:0:2026-01-01'] },
    { limit: '10' },
    V1,
  );
  assert.equal(out.data[0].caseId, '9');
  assert.deepEqual(out.meta, { total: 3, limit: 10, offset: 0 });
});

test('LIST_ACCESS_REVIEWS v1 returns reviews as data', async () => {
  const row = '1:2026-01-01:2026-01-31:OPEN:boss:5::';
  const out = await RESPONSE_MAPPERS.LIST_ACCESS_REVIEWS({ data: ['X', '1', row] }, {}, V1);
  assert.equal(out.data[0].id, '1');
  assert.deepEqual(out.meta, { total: 1, limit: 20, offset: 0 });
});

test('ACC_LIST v1 parses rows, reports null total, rejects short rows', async () => {
  const out = await RESPONSE_MAPPERS.ACC_LIST({ data: ['ACC_LIST', '1:R-1:ACTIVE:10.00:0.00:Ann'] }, {}, V1);
  assert.deepEqual(out.data[0], {
    id: '1',
    accountRef: 'R-1',
    status: 'ACTIVE',
    balance: '10.00',
    holdAmount: '0.00',
    holderName: 'Ann',
  });
  assert.deepEqual(out.meta, { total: null, limit: 20, offset: 0 });
  assert.deepEqual((await RESPONSE_MAPPERS.ACC_LIST({ data: ['ACC_LIST', '0'] }, {}, V1)).data, []);
  await assert.rejects(RESPONSE_MAPPERS.ACC_LIST({ data: ['ACC_LIST', '1:R-1'] }, {}, V1), /ACC_LIST row/);
});

test('ACC_LIST legacy path returns the raw body untouched', async () => {
  const body = { data: ['ACC_LIST', '1:R-1:ACTIVE:10.00:0.00:Ann'] };
  assert.deepEqual(await RESPONSE_MAPPERS.ACC_LIST(body, {}, {}), body);
});

test('LOAN_LIST v1 parses rows', async () => {
  const out = await RESPONSE_MAPPERS.LOAN_LIST({ data: ['LOAN_LIST', '4:L-9:ACTIVE:5000:1000:Bob'] }, {}, V1);
  assert.equal(out.data[0].loanRef, 'L-9');
  assert.deepEqual(out.meta, { total: null, limit: 20, offset: 0 });
  assert.deepEqual((await RESPONSE_MAPPERS.LOAN_LIST({ data: ['LOAN_LIST', '0'] }, {}, V1)).data, []);
});

test('DEP_LIST v1 parses rows', async () => {
  const out = await RESPONSE_MAPPERS.DEP_LIST({ data: ['DEPOSITS', '2:d@t.co:1000:USD:12:ACTIVE:50.00'] }, {}, V1);
  assert.equal(out.data[0].principal, '1000');
  assert.deepEqual(out.meta, { total: null, limit: 20, offset: 0 });
});

test('CARD_LIST v1 parses rows', async () => {
  const out = await RESPONSE_MAPPERS.CARD_LIST(
    { data: ['CARDS', '3:C-1:c@t.co:DEBIT:ACTIVE:5000:4000:1000:****1'] },
    {},
    V1,
  );
  assert.equal(out.data[0].cardRef, 'C-1');
  assert.deepEqual(out.meta, { total: null, limit: 20, offset: 0 });
});

test('PAY_POLICY_LIST v1 carries the COBOL total', async () => {
  const out = await RESPONSE_MAPPERS.PAY_POLICY_LIST(
    { data: ['PAY_POLICIES', '3 ', 'USD:1000:500:2:50:10:1'] },
    {},
    V1,
  );
  assert.equal(out.data[0].currency, 'USD');
  assert.equal(out.data[0].enabled, true);
  assert.deepEqual(out.meta, { total: 3, limit: 20, offset: 0 });
  assert.deepEqual((await RESPONSE_MAPPERS.PAY_POLICY_LIST({ data: ['PAY_POLICIES', '0 '] }, {}, V1)).data, []);
});

test('IMP_BATCH_LIST v1 carries the COBOL total', async () => {
  const out = await RESPONSE_MAPPERS.IMP_BATCH_LIST(
    { data: ['IMP_BATCHES', '2 ', '9:B-1:core:LEDGER:POSTED:10:9:1:9'] },
    {},
    V1,
  );
  assert.equal(out.data[0].code, 'B-1');
  assert.deepEqual(out.meta, { total: 2, limit: 20, offset: 0 });
});

test('RPT_TEMPLATE_LIST v1 carries the COBOL total', async () => {
  const out = await RESPONSE_MAPPERS.RPT_TEMPLATE_LIST(
    { data: ['RPT_TEMPLATES', '1 ', '5:T-1:Monthly:TRIAL_BALANCE:CSV:1:Month end'] },
    {},
    V1,
  );
  assert.equal(out.data[0].code, 'T-1');
  assert.deepEqual(out.meta, { total: 1, limit: 20, offset: 0 });
});
