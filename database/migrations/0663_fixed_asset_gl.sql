-- PR-702: Fixed Asset — GL link on registry for revaluations.
-- (Depreciation/disposal link via their own tables from 0662.)

ALTER TABLE fixed_asset
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER gl_gain_loss_account;
