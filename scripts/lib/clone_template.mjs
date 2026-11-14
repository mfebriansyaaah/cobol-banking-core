// Single source for the clone-budget template identity (DRY-00A).
//
// scripts/check_clone_budget.mjs and scripts/audit_complexity.mjs must
// agree on what "the template" is; two hardcoded 669s drifted before
// (clone budget said 669 lines, complexity baseline reported 0 files at
// 669 while the template was already 637).
export const TEMPLATE = 'cost_center_core.cob';
export const TEMPLATE_LINES = 637;
export const SIM_THRESHOLD = 0.9;
