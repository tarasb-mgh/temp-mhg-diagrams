# Quickstart: Unified Workbench Tag Center

## Goal

Validate unified tagging behavior in one Tag Center entry point with separate `User Tags` and `Review Tags` modes, consistent delete guardrails, and full user-profile tag visibility.

## Prerequisites

- Backend and workbench frontend are from the same deploy cycle
- Access to `https://workbench.dev.mentalhelp.chat`
- Accounts for:
  - moderator-or-higher (rights-management and definition lifecycle checks)
  - standard operator (assignment checks without capability gating)
- Seed data:
  - at least one user tag and one review tag
  - at least one review record referencing a review tag
  - at least one user with multiple assigned user tags

## Validation Steps

### 1) Unified Entry and Mode Separation

1. Open Tag Center from workbench navigation.
2. Confirm both modes are available: `User Tags`, `Review Tags`.
3. Switch modes.

Expected result:
- One entry point is used for tagging workflows.
- User assignment controls appear only in `User Tags`.
- Review-tag definition controls appear only in `Review Tags`.

### 2) User Tag Definition Lifecycle

1. In `User Tags`, create a new user tag.
2. Edit the tag metadata.
3. Archive the tag.
4. Unarchive the tag.

Expected result:
- Create/edit/archive/unarchive complete successfully.
- Archived tag cannot be newly assigned while archived.

### 3) User Tag Assignment Without Capability Gating

1. Select any user.
2. Assign a user tag.
3. Unassign the same tag.

Expected result:
- Assignment and unassignment work for all users.
- Assignment action does not require capability gating.
- User state updates without navigating away.

### 4) User Profile Shows All Assigned Tags

1. Assign multiple user tags to one user.
2. Open that user's profile.
3. Refresh profile.

Expected result:
- Profile displays all currently assigned user tags.
- Displayed tags remain consistent after refresh.

### 5) Review Tag Delete Guardrail

1. In `Review Tags`, pick a tag referenced by any active or historical review record.
2. Attempt to delete it.
3. Archive the same tag instead.

Expected result:
- Delete is blocked.
- Blocked response includes reason + next action (archive).
- Archive succeeds.

### 6) Search and Filter Semantics

1. Search by partial user name.
2. Search by partial email.
3. Search by partial tag name.
4. Apply combined filters.

Expected result:
- Search is case-insensitive and partial-match based.
- Combined filters apply with AND logic.

### 7) Rights-Management and Definition Gating

1. Use an account with read-only rights for definitions.
2. Attempt create/edit/archive/delete.
3. Use moderator-or-higher account and repeat.

Expected result:
- Restricted accounts cannot execute gated definition/rights actions.
- Authorized accounts can execute gated actions.
- Rights-management controls remain secondary and appear contextually in the assignments header.
- Refresh action is icon-based and save action uses compact label `Save`.

### 8) UX Noise Reduction and Layout Density

1. Open `User Tags` mode on desktop width (>=1280).
2. Confirm definitions and assignments are visually primary and easily scannable.
3. Confirm rights-management actions are integrated into the assignments header as compact secondary controls.
4. Repeat on mobile width (~375).

Expected result:
- Primary actions stay in focus with reduced whitespace noise.
- Layout remains readable and non-overloaded on desktop and mobile.
- Contextual low-frequency controls stay discoverable without introducing extra sections.

### 8.1) Desktop Viewport Containment (Required)

1. Open `User Tags` mode at desktop width (>=1280).
2. Verify the route fits the visible workbench content viewport without requiring outer page scroll.
3. In `User Tag Assignments`, confirm user list and assigned-tags list use internal scroll when data volume is high.
4. Switch to `Review Tags` mode and confirm long definition lists scroll inside the definitions panel.

Expected result:
- Desktop route content remains within one visible viewport.
- Internal panel lists scroll; outer route/page does not expand.

### 8.2) Mobile Scroll Behavior (Required)

1. Open `User Tags` mode at mobile width (~375).
2. Scroll the page through both `User Tag Definitions` and `User Tag Assignments`.
3. Confirm no horizontal overflow appears.

Expected result:
- Mobile keeps natural vertical page scrolling.
- Section cards remain visually separated and all controls are reachable.

### 9) Reliability Gate (SC-003)

1. Run automated E2E suite in dev for each happy flow.
2. Execute 10 consecutive runs per happy flow.
3. Count blocking failure events per run.

Expected result:
- No more than 2 runs per flow contain a blocking user-visible failure event.
- Evidence is recorded per run.

## Required E2E Coverage

- User tag create/edit/archive/unarchive
- User tag assign/unassign
- Search/filter behavior
- Profile full tag visibility
- Review tag create/edit/archive/delete guardrail
- Rights/permission denial paths
- Error handling consistency (`invalid input`, `insufficient permission`, `missing target`, `conflicting state`)

## Evidence to Capture

- Screenshots:
  - Tag Center (`User Tags` mode)
  - Tag Center (`Review Tags` mode)
  - User profile with multiple assigned tags
  - Blocked review-tag delete messaging
- Network traces for:
  - successful assign/unassign
  - blocked delete (conflict)
  - rights-gated denied action
- SC-003 run summary (10-run sequence per happy flow)

## UI Review Gate (Required Before Merge)

Use the `frontend-ui-ux-engineer` quality baseline for final visual verification.

- Visual hierarchy is clear: primary actions are obvious, secondary controls are de-emphasized.
- Spacing and density are consistent across cards, rows, and control groups (no excessive whitespace noise).
- Interactive states are present and readable for hover/focus/disabled on all actionable controls.
- Mobile layout (around 375px) has no horizontal overflow and keeps touch targets usable.
- Assignment and definition rows remain legible with long tag names (wrapping/truncation behaves intentionally).
- Destructive actions are visually distinct and not easy to trigger accidentally.

## Phase 7 Automation Evidence Mapping

- Reliability gate (`T048`):
  - `chat-ui/tests/e2e/workbench/tag-center.spec.ts` → `workbench: tag center reliability gate` (10 serial runs)
  - Artifacts: `test-results/tag-center-reliability-run-<n>.png`
- Accessibility audit (`T050`):
  - `chat-ui/tests/e2e/workbench/tag-center.spec.ts` → `workbench: tag center accessibility checks`
  - Evidence includes keyboard navigation and semantic control discoverability.
- Responsive validation (`T051`):
  - `chat-ui/tests/e2e/workbench/tag-center.spec.ts` → `workbench: tag center responsive validation`
  - Artifacts: `test-results/tag-center-responsive-mobile-375.png`, `...-tablet-768.png`, `...-desktop-1280.png`
- PWA installability regression (`T052`):
  - `chat-ui/tests/e2e/workbench/tag-center.spec.ts` → `workbench: pwa and route regression`
  - Validates manifest reachability and service-worker API availability.
- Final route/navigation regression (`T054`):
  - `chat-ui/tests/e2e/workbench/tag-center.spec.ts` → `legacy tag routes are not primary and unified route is stable`

## Documentation Drift Check (T053)

- `spec.md`: updated with UX priority requirement for contextual secondary rights controls and noise reduction (`FR-018` + US1 scenario 8).
- `plan.md`: updated with implementation decision for contextual rights controls in assignments header.
- `spec.md` and `plan.md`: updated with desktop single-viewport containment + mobile natural scroll requirements (`FR-019`, `FR-020`, shell-aware viewport layout strategy).
