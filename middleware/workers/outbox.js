#!/usr/bin/env node
// Notification outbox worker: claim due rows from COBOL, deliver them, and
// mark the outcome. Run it on a schedule (cron/systemd); every invocation is
// a bounded batch. A successful money movement never waits on this worker:
// notifications that cannot be delivered stay observable (PENDING/FAILED)
// and age into the dead-letter state instead of rolling anything back.
//
// Transports:
//   smtp (default) - real delivery via the mailer (needs SMTP_* env).
//   mailpit        - same SMTP path against a local Mailpit (EMAIL_PROVIDER
//                    resolves the host/port when SMTP_* is unset).
//   log            - append the full delivery record as JSONL to
//                    OUTBOX_LOG_FILE (development/tests; never production,
//                    since it would mark mail delivered without sending).
// Operational logs go to stdout WITHOUT codes or message bodies (redacted);
// the delivery record (log transport) or the SMTP provider holds content.
//
// Usage: node middleware/workers/outbox.js [--once] [--limit N] [--worker ID]
//   OUTBOX_TRANSPORT=smtp node middleware/workers/outbox.js --once
//   OUTBOX_TRANSPORT=log OUTBOX_LOG_FILE=/tmp/outbox.log node middleware/workers/outbox.js --once
//   cron: * * * * * OUTBOX_TRANSPORT=smtp node /opt/cobol-banking-core/middleware/workers/outbox.js --once --limit 100

import { appendFile } from 'node:fs/promises';
import { invoke } from '../src/invoker.js';
import { resetPool } from '../src/pool.js';
import { toHttp } from '../src/result.js';
import { createMailer, mailerFrom, verificationSubject } from '../services/mailer.js';
import { pingCheck, pingFail } from '../services/integrations/ops/healthchecks.js';
import { sendAlert } from '../services/integrations/ops/notify.js';

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i === -1 ? fallback : process.argv[i + 1];
}

function subjectFor(purpose) {
  if (purpose === 'EMAIL_CHANGED') return 'Your account email was changed';
  if (purpose === 'MFA_RECOVERY_NOTICE') return 'Your account MFA was reset';
  if (purpose === 'NEW_DEVICE') return 'New sign-in to your account';
  if (purpose === 'DORMANT_NOTICE') return 'Your account has been inactive';
  return verificationSubject(purpose);
}

function textFor({ purpose, code, detail }) {
  if (purpose === 'EMAIL_CHANGED') {
    return `Your account email was changed to ${detail}. If this was not you, contact support.`;
  }
  if (purpose === 'MFA_RECOVERY_NOTICE') {
    return 'Your multi-factor authentication was reset by an administrator. If this was not you, contact support immediately.';
  }
  if (purpose === 'NEW_DEVICE') {
    return `A new sign-in to your account was detected from ${detail}. If this was not you, change your password and contact support.`;
  }
  if (purpose === 'DORMANT_NOTICE') {
    return 'Your account has not been used for a while. Sign in soon to keep it active; it will be suspended after the grace period. Contact support if you need help.';
  }
  return `Your verification code is ${code}`;
}

function logLine(event, fields = {}) {
  // Redacted by construction: callers pass id/to/purpose only, never code.
  console.log(JSON.stringify({ ts: new Date().toISOString(), event, ...fields }));
}

async function main() {
  const limit = Number(arg('--limit', '50')) || 50;
  const worker = arg('--worker', `worker-${process.pid}`);
  const transport = process.env.OUTBOX_TRANSPORT ?? 'smtp';
  const logFile = process.env.OUTBOX_LOG_FILE;

  if (transport !== 'smtp' && transport !== 'mailpit' && transport !== 'log') {
    console.error(`OUTBOX_TRANSPORT must be smtp, mailpit, or log (got ${transport})`);
    process.exit(1);
  }
  if (transport === 'log' && !logFile) {
    console.error('OUTBOX_LOG_FILE is required with OUTBOX_TRANSPORT=log');
    process.exit(1);
  }

  const mailer = createMailer();
  const from = mailerFrom();
  const claimedRaw = await invoke('OUTBOX_CLAIM', [String(limit), worker]);
  const claimed = toHttp(claimedRaw);
  if (claimed.status !== 200) throw new Error(`claim failed: ${claimed.body.error}`);
  // Multi-row COBOL output packs rows with ';' inside one pipe field.
  const rows = claimed.body.data.length > 1 ? claimed.body.data[1].split(';').filter((r) => r) : [];
  if (rows.length === 0) {
    logLine('outbox_idle', { worker });
    return;
  }

  for (const row of rows) {
    // id:recipient:purpose:code:detail (detail may be empty).
    const [id, to, purpose, code = '', detail = ''] = row.split(':');
    const subject = subjectFor(purpose);
    const text = textFor({ purpose, code, detail });
    let sent = false;
    let error = '';
    try {
      if (
        purpose !== 'SIGNUP' &&
        purpose !== 'PASSWORD_RESET' &&
        purpose !== 'EMAIL_CHANGE' &&
        purpose !== 'EMAIL_CHANGED' &&
        purpose !== 'MFA_RECOVERY' &&
        purpose !== 'MFA_RECOVERY_NOTICE' &&
        purpose !== 'NEW_DEVICE' &&
        purpose !== 'DORMANT_NOTICE'
      ) {
        error = `unknown purpose ${purpose}`;
      } else if (transport === 'log') {
        await appendFile(
          logFile,
          JSON.stringify({ ts: new Date().toISOString(), id, to, purpose, subject, text }) + '\n',
        );
        sent = true;
      } else {
        sent = await mailer.deliver({ from, to, subject, text });
        if (!sent) error = 'delivery failed';
      }
    } catch (err) {
      error = String((err && err.message) || err).slice(0, 200);
    }
    const markedRaw = await invoke('OUTBOX_MARK', [id, sent ? 'SENT' : 'FAILED', error, worker]);
    const marked = toHttp(markedRaw);
    if (marked.status !== 200) {
      logLine('outbox_mark_failed', { id, to, purpose, error: marked.body.error });
      continue;
    }
    const finalState = marked.body.data[1];
    if (finalState === 'DEAD') {
      logLine('outbox_dead_letter', { id, to, purpose });
      // Alert carries ids/statuses only — never the recipient (PII).
      await sendAlert('OUTBOX_DEAD', { id, purpose });
    } else if (sent) {
      logLine('outbox_sent', { id, to, purpose });
    } else {
      logLine('outbox_failed', { id, to, purpose, error: error.slice(0, 120) });
    }
  }
}

try {
  await main();
  // Liveness ping (PR-095): best-effort, never fails the job.
  await pingCheck(process.env.OUTBOX_CHECK_ID);
} catch (err) {
  console.error(
    JSON.stringify({
      ts: new Date().toISOString(),
      event: 'outbox_worker_error',
      error: String((err && err.message) || err).slice(0, 200),
    }),
  );
  await pingFail(process.env.OUTBOX_CHECK_ID, 'outbox worker crashed');
  process.exit(1);
} finally {
  // Drop pooled COBOL workers so --once actually terminates. In file mode
  // there is nothing to close; in pool mode the spawned --serve processes
  // would otherwise keep the event loop alive forever.
  await resetPool();
}
