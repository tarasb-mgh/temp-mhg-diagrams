# Checklist: Role-Based UX Rerun Gate (029)

**Purpose**: Execute this checklist immediately after authentication blockers are resolved.
**Scope**: Workbench UX wayfinding and discoverability validation in dev.

## A. Environment and Access Gate

- [ ] A01 Confirm Workbench URL is `https://workbench.dev.mentalhelp.chat`.
- [ ] A02 Confirm API URL is `https://api.dev.mentalhelp.chat`.
- [ ] A03 Confirm frontend and backend are from the same deploy cycle.
- [ ] A04 Confirm approved role account matrix is available (owner/admin/reviewer/researcher/group-admin).
- [ ] A05 Confirm each role can complete sign-in (or log explicit blocker with evidence).

## B. Data Preconditions

- [ ] B01 At least one reviewable session exists for review flow validation.
- [ ] B02 At least one group has enough data for group navigation checks.
- [ ] B03 At least one survey instance with response details exists for deep-flow checks.
- [ ] B04 Required permissions are present for each role under test.

## C. Role-by-Role Evidence Capture

For each tested role:

- [ ] C01 Capture entry/sign-in screen.
- [ ] C02 Capture post-login sidebar/menu.
- [ ] C03 Capture one deep-flow screen (detail page).
- [ ] C04 Capture the return path (back/breadcrumb/section link).
- [ ] C05 Record whether next-step guidance is visible and understandable.

## D. Wayfinding Quality Checks

- [ ] D01 User can identify current location from screen context.
- [ ] D02 User can return one level up without confusion.
- [ ] D03 User can find target section in three clicks or fewer.
- [ ] D04 No dead-end state without clear next action.
- [ ] D05 Labels are unambiguous and consistent with IA terminology.

## E. Findings and Backlog

- [ ] E01 Every issue includes severity, role, flow, step, and impact.
- [ ] E02 Every issue includes screenshot or log evidence path.
- [ ] E03 Every issue includes proposed remediation and owner team.
- [ ] E04 P1/P2/P3 prioritization is applied consistently.
- [ ] E05 All unresolved P1 blockers are explicitly listed in final summary.

## F. Baseline vs Rerun Comparison

- [ ] F01 Compare first-click success against baseline.
- [ ] F02 Compare completion without manual guidance against baseline.
- [ ] F03 Compare back-navigation confidence against baseline.
- [ ] F04 Confirm reduction in dead-end navigation states.
- [ ] F05 Confirm no unresolved P1 wayfinding/discoverability blockers remain.
- [ ] F06 Enforce rerun fail gate: if any required role is blocked, mark rerun as failed until full 5-role rerun completes.

## G. Documentation Compliance

- [ ] G01 `spec.md`, `plan.md`, `research.md`, `quickstart.md`, and `tasks.md` are updated as needed.
- [ ] G02 This checklist is marked with pass/fail outcomes and dated.

## H. Evidence Retention Verification

- [ ] H01 Baseline artifact directory is recorded as `artifacts/workbench-ux-audit-20260312-232652/`.
- [ ] H02 Raw baseline screenshots/logs are retained with no redaction.
- [ ] H03 Retention expiry date is recorded as baseline run date + 90 days.

## I. Usability Acceptance Checks (SC-003)

- [ ] I01 For each role, 3 critical flows are executed using only in-product cues.
- [ ] I02 For each role/flow, failed attempts are recorded and `<= 1`.
- [ ] I03 For each role, no external docs/chat help is used during scripted runs.
- [ ] I04 At least 80% of tested users satisfy SC-003 rule across the 3-flow script.
- [ ] I05 SC-003 pass/fail result is documented in rerun summary with evidence links.

## J. Gate Validation Log (Phase 6)

- [X] J01 Rerun fail/pass gate logic evaluated against current role matrix state.
- [X] J02 Gate outcome recorded as `failed` when one or more required roles are blocked.
- [X] J03 Evaluation references are linked to `research.md` rerun results section.
