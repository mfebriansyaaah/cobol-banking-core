# Security History Review

- Date: 2026-11-16
- Scope: `gitleaks detect --source . --config .gitleaks.toml` over full git history (2362 commits).
- Report: `/tmp/opencode/gitleaks-history.json` (redacted), raw inspected locally and not committed.

| Rule | File | Commit | Line | Classification | Disposition |
| --- | --- | --- | ---: | --- | --- |
| generic-api-key | middleware/test/integrations/bot.test.js | 44c9cbaf | 89 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | middleware/test/integrations/bot.test.js | 44c9cbaf | 99 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | middleware/test/integrations/bot.test.js | 44c9cbaf | 110 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | middleware/test/integrations/bot.test.js | 44542b57 | 85 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | middleware/test/integrations/bot.test.js | 44542b57 | 90 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | middleware/test/integrations/bot.test.js | 44542b57 | 95 | SYNTHETIC_TEST_FIXTURE | keep, documented |
| generic-api-key | CODING_STANDARDS.md | 4a22bc3c | 112 | FALSE_POSITIVE | docs phrase, file deleted; documented |

Notes:

- The 6 `bot.test.js` findings are the same 32-char synthetic fixture
  password used to exercise captcha/breach gates (value redacted here;
  see the test file). Not a live credential, not used outside tests.
- The `CODING_STANDARDS.md` finding is a docs prose false positive
  (password-related wording); file no longer exists at HEAD.
- Live-credential count: 0.
- Worktree scan (`gitleaks detect --source . --no-git`) is clean: 0 findings.
