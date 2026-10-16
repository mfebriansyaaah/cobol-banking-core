import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createMailer, verificationSubject } from '../src/mailer.js';
import { metricsText } from '../src/observability.js';

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

test('a failing SMTP does not throw and is counted', async () => {
  const saved = {
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT,
    timeout: process.env.SMTP_TIMEOUT_MS,
  };
  process.env.SMTP_HOST = '127.0.0.1';
  process.env.SMTP_PORT = '1';
  process.env.SMTP_TIMEOUT_MS = '300';
  try {
    const lines = [];
    const mailer = createMailer({ logger: (line) => lines.push(line) });
    await assert.doesNotReject(() => mailer.sendVerification({ to: 'a@test.com', purpose: 'SIGNUP', code: '123456' }));
    assert.ok(lines.some((l) => l.event === 'mail_failed'), 'logs a mail_failed event');
    assert.match(metricsText(), /gateway_mailer_failed_total \d+/);
  } finally {
    for (const [k, v] of [['SMTP_HOST', saved.host], ['SMTP_PORT', saved.port], ['SMTP_TIMEOUT_MS', saved.timeout]]) {
      if (v === undefined) delete process.env[k]; else process.env[k] = v;
    }
  }
});

test('the verification subject depends on the purpose', () => {
  assert.equal(verificationSubject('PASSWORD_RESET'), 'Reset your password');
  assert.equal(verificationSubject('EMAIL_CHANGE'), 'Confirm your new email address');
  assert.equal(verificationSubject('SIGNUP'), 'Verify your account');
  assert.equal(verificationSubject(undefined), 'Verify your account');
});
