import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createMailer } from '../src/mailer.js';

test('the development stub logs the event without the code', async () => {
  const savedHost = process.env.SMTP_HOST;
  const savedDebug = process.env.MAIL_DEBUG;
  delete process.env.SMTP_HOST;
  delete process.env.MAIL_DEBUG;
  const lines = [];
  try {
    const mailer = createMailer({ logger: (line) => lines.push(line) });
    await mailer.sendVerification({ to: 'a@test.com', purpose: 'SIGNUP', code: '123456' });
    const line = lines.find((l) => l.event === 'verification_code');
    assert.ok(line);
    assert.equal(line.to, 'a@test.com');
    assert.equal(line.purpose, 'SIGNUP');
    assert.equal(line.code, undefined);
  } finally {
    if (savedHost !== undefined) process.env.SMTP_HOST = savedHost;
    if (savedDebug !== undefined) process.env.MAIL_DEBUG = savedDebug;
  }
});

test('MAIL_DEBUG shows the code outside production', async () => {
  const savedHost = process.env.SMTP_HOST;
  const savedDebug = process.env.MAIL_DEBUG;
  const savedEnv = process.env.NODE_ENV;
  delete process.env.SMTP_HOST;
  process.env.MAIL_DEBUG = '1';
  process.env.NODE_ENV = 'test';
  const lines = [];
  try {
    const mailer = createMailer({ logger: (line) => lines.push(line) });
    await mailer.sendVerification({ to: 'a@test.com', purpose: 'SIGNUP', code: '123456' });
    assert.equal(lines[0].code, '123456');
  } finally {
    if (savedHost === undefined) delete process.env.SMTP_HOST; else process.env.SMTP_HOST = savedHost;
    if (savedDebug === undefined) delete process.env.MAIL_DEBUG; else process.env.MAIL_DEBUG = savedDebug;
    if (savedEnv === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = savedEnv;
  }
});
