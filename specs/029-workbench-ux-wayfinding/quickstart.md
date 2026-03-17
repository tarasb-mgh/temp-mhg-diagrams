# Quickstart: Workbench UX Wayfinding Initiative (029)

**Branch**: `029-workbench-ux-wayfinding`  
**Primary Environment**: `https://workbench.dev.mentalhelp.chat`  
**API Environment**: `https://api.dev.mentalhelp.chat`

---

## Purpose

Use this guide to:

1. Run the baseline role-based UX audit.
2. Prepare implementation-ready UX findings.
3. Execute the post-auth-unblock rerun using the same benchmark.

---

## Prerequisites

- Approved dev accounts for target roles:
  - owner
  - admin
  - reviewer
  - researcher
  - group-admin
- OTP fallback is enabled and approved as the primary dev sign-in path for audit runs.
- Confirm frontend and backend are from the same deploy cycle.
- At least one reviewable session exists for deep-flow checks.
- At least one survey instance exists with response data for detail navigation checks.

---

## Baseline Execution Steps

### 1) Confirm access prerequisites

- Validate each target account can attempt sign-in.
- If sign-in fails, capture blocker details (message, screenshot, step).
- Mark blockers as P1 findings in `research.md`.

### 2) Capture role evidence

For each role, capture the same evidence set:

- Entry/sign-in screen
- Post-login sidebar/menu
- One deep-flow screen
- Return path to parent section

Store evidence under:

- `artifacts/workbench-ux-audit-<timestamp>/screenshots/`
- `artifacts/workbench-ux-audit-<timestamp>/results.json`

### 3) Record normalized findings

For each issue, include:

- severity
- impacted role
- flow and step
- business/user impact
- evidence path
- proposed solution
- owner team (frontend/backend/product)

### 3a) Validate "without manual guidance" rule

For each scripted flow and role, record the validation outcome using this exact rule:

- Only in-product UI cues were used.
- No external documentation or chat help was used.
- Failed attempts per flow are `<= 1`.

If any condition fails, mark the flow as not compliant for SC-003.

### 4) Build implementation backlog

- Convert findings into prioritized tasks (P1/P2/P3) in `tasks.md`.
- Keep language and labels consistent with planned IA terminology.

---

## Post-Fix Rerun Steps (After Auth Unblock)

1. Execute the checklist in `checklists/requirements.md`.
2. Re-run the same role matrix and scenario set used in baseline (all 5 roles are mandatory).
3. Compare baseline vs rerun outcomes for:
   - first-click success
   - ability to recover/backtrack
   - completion without manual guidance
4. Apply the measurable SC-003 rule during rerun scoring:
   - only in-product cues
   - no external docs/chat help
   - no more than one failed attempt per flow
5. Update `research.md` with before/after summary and unresolved gaps.
6. Mark rerun as failed if any of the 5 required roles is blocked.

### 7) Execute first-use validation script and scoring

Run the following script for each required role and each of 3 critical flows:

1. Start from Workbench home.
2. Ask user to reach the target screen without external docs/help.
3. Record whether first click enters the correct top-level section.
4. Record failed attempts count until flow completion.
5. Verify whether guidance patterns are visible:
   - purpose hint
   - next-step hint
   - consequence visibility for risky actions
6. Verify return-path behavior (breadcrumb/back/section link).

Scoring model per role:

- `SC3_role_score = compliant_flows / 3`
- A flow is compliant only if:
  - in-product cues only
  - no external docs/chat help
  - failed attempts `<= 1`
- Role pass threshold: `SC3_role_score >= 0.8`

Global rerun SC-003 result:

- `SC3_global_pass = roles_passed / 5 >= 0.8`

---

## Deliverables Checklist

- Updated `research.md` with baseline and rerun evidence
- Updated `tasks.md` with prioritized remediation backlog
- Completed `checklists/requirements.md`
- Final outcome note in `spec.md` appendix (resolved vs remaining P1 blockers)

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Google sign-in blocked with "browser or app may not be secure" | Automation/auth policy mismatch | Use approved dev auth workaround and document exact method. |
| OTP fallback not available | Dev auth config drift | Restore OTP fallback for approved test accounts before continuing baseline/rerun. |
| Role logs in but deep flow is empty | Missing seed/test data | Coordinate with data owner and rerun deep-flow step after data is present. |
| Menu differs unexpectedly between runs | Environment mismatch | Reconfirm deploy cycle alignment before continuing. |
| Findings are hard to compare between runs | Inconsistent scenario set | Enforce identical role matrix and flow checklist for baseline and rerun. |
