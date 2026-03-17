# Feature Specification: Workbench UX Wayfinding and Information Architecture Overhaul

**Feature Branch**: `029-workbench-ux-wayfinding`  
**Created**: 2026-03-12  
**Status**: Draft  
**Input**: User description: "Create a global speckit initiative to improve Workbench UX: analyze the current product with Playwright across multiple roles, capture menu and flow screenshots, convert UX issues into tasks, and propose solutions focused on intuitive navigation without requiring a manual."

## Clarifications

### Session 2026-03-12

- Q: Which dev authentication approach should be used to unblock role-based UX audits? → A: Use OTP fallback in Workbench dev as the primary audit login method.
- Q: What role coverage threshold should be mandatory for baseline and rerun acceptance? → A: Require all 5 roles (owner, admin, reviewer, researcher, group-admin) in both baseline and rerun.
- Q: How should "without manual guidance" be measured for acceptance? → A: User completes scripted flow with only in-product cues, no external docs/help, and at most one failed attempt per flow.
- Q: What evidence retention policy should apply to UX audit screenshots/logs? → A: Store full raw evidence without redaction for 90 days.
- Q: What is the rerun gate policy if any role in the 5-role matrix is blocked? → A: Mark rerun as failed until blocker is removed and full 5-role rerun is completed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Role-Based UX Baseline Audit (Priority: P1)

A product team runs a role-based UX audit of Workbench in the dev environment and produces a single artifact: for each role, it records sign-in outcome, visible menu items, key completed flows, screenshots, and blockers (including auth blockers).

**Why this priority**: Without an objective role-based UX map, navigation fixes are guesswork; users are currently getting lost in the interface.

**Independent Test**: For each target role, there is a completed audit sheet with status (success/blocker), navigation screenshots, and a severity-labeled UX issue list.

**Acceptance Scenarios**:

1. **Given** the target role list is defined, **When** a Playwright audit runs on `https://workbench.dev.mentalhelp.chat`, **Then** each role has recorded sign-in outcome, visible menu sections, and one deep-flow scenario.
2. **Given** a role cannot sign in due to an auth blocker, **When** the audit completes, **Then** the blocker is documented as a P1 issue with reproducibility steps, evidence, and owner.
3. **Given** the audit is complete, **When** the team opens the report, **Then** it sees a unified UX backlog with severity, impact, and recommended remediation.

---

### User Story 2 - Intuitive Navigation and Menu Clarity (Priority: P1)

A user in any operational role (owner/admin/reviewer/researcher/group-admin) can understand where they are, where to go next, and how to go back without external documentation.

**Why this priority**: The main pain point is user disorientation in flows and unclear Workbench structure; this directly affects task speed and error rate.

**Independent Test**: Target-role users complete key scenarios (find section, enter detail screen, return safely) without prompts and without dead ends.

**Acceptance Scenarios**:

1. **Given** a user opens Workbench after sign-in, **When** they view the sidebar menu, **Then** section names and grouping clearly match intent.
2. **Given** a user is on a deep screen (instance detail, group settings, survey responses), **When** they need to move up one level, **Then** an obvious path exists (back, breadcrumb, or section entry point).
3. **Given** a user switches between related tasks, **When** they complete an action, **Then** the UI presents a clear next step instead of leaving a dead-end state.

---

### User Story 3 - First-Use Guidance for Complex Flows (Priority: P2)

A new or infrequent user gets built-in guidance (microcopy, hints, contextual descriptions) to understand interface logic faster and avoid errors in critical scenarios.

**Why this priority**: Even with better menu structure, complex admin scenarios remain cognitively heavy without contextual guidance.

**Independent Test**: A new user completes 3 critical scenarios on first attempt without reading external documentation.

**Acceptance Scenarios**:

1. **Given** a user opens a complex section for the first time, **When** the section loads, **Then** they see a short explanation of "what this is" and "what to do next."
2. **Given** an action is risky or potentially irreversible, **When** the user initiates it, **Then** the UI clearly explains consequences and rollback/cancel path.
3. **Given** a user finishes a step in a wizard/form, **When** success is confirmed, **Then** the UI shows the next logical step nearby.

---

### Edge Cases

- What happens if some roles cannot sign in (Google OAuth block, awaiting approval, missing permissions)?
- How should the audit proceed if menu structure differs by role and environment?
- What if a required scenario needs specific data (e.g., completed responses) and data is missing?
- How do we avoid false UX conclusions if frontend and backend are not from the same dev deploy cycle?

## Baseline Blocker List (2026-03-12)

### P1 Blockers

- Google-auth sign-in path blocks baseline completion for required roles in automated runs.
- Reviewer and researcher accounts were not available in the baseline input set, blocking full 5-role completion.
- Deep-flow/menu evidence could not be captured for authenticated states due to auth blocker chain.

### P2 Blockers

- Sign-in method discoverability in dev is ambiguous when OTP fallback is not explicit on entry.
- Repeated unauthenticated `401` noise reduces QA signal quality for UX validation.
- Auth-entry localization consistency is not enforced as a gate.

### P3 Blockers

- No additional P3 blockers were recorded in this baseline.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The team MUST run a role-based Workbench UX audit in dev using a pre-approved role/account matrix.
- **FR-002**: The audit MUST include at minimum: sign-in screen, post-login sidebar/menu screen, and at least one deep scenario per role.
- **FR-003**: Every UX defect found MUST include: severity, impacted role, reproduction steps, evidence (screenshot/log), suspected cause, and proposed solution.
- **FR-004**: All defects MUST be converted into a prioritized task backlog (P1/P2/P3) with an owner team (frontend/backend/product).
- **FR-005**: Workbench MUST provide explicit wayfinding mechanisms on deep screens: current-context visibility and an obvious path back.
- **FR-006**: Menu information architecture MUST be consistent: shared terminology, logical grouping, and no ambiguous/duplicate labels.
- **FR-007**: Complex flows MUST include first-use UX guidance (context text, next-step hints, consequence explanations).
- **FR-008**: The team MUST run a post-fix UX pass and record outcomes using the same baseline criteria.
- **FR-009**: For Workbench UX audits in dev, the primary automated sign-in method MUST be OTP fallback for approved test accounts until Google auth automation is verified as stable.
- **FR-010**: Baseline and rerun acceptance MUST include the full 5-role matrix: owner, admin, reviewer, researcher, and group-admin.
- **FR-011**: "Without manual guidance" MUST be validated using scripted flows completed with only in-product UI cues, no external docs/chat help, and no more than one failed attempt per flow.
- **FR-012**: UX audit screenshots and logs MUST be retained in raw form (no redaction) for 90 days to support triage and historical comparison.
- **FR-013**: If any role in the required 5-role matrix is blocked during rerun, rerun acceptance MUST fail until the blocker is removed and the full matrix rerun is completed.

### Key Entities *(include if feature involves data)*

- **Role UX Audit Matrix**: Table of roles/accounts/accessibility with sign-in outcomes and available flows.
- **UX Finding**: Normalized UX issue record (severity, impact, evidence, recommendation, owner).
- **Navigation Node**: A menu item or key screen in the user journey.
- **Critical Flow**: A Workbench step sequence where users frequently lose context or make errors.
- **Remediation Task**: A prioritized speckit/Jira task that resolves a specific UX issue.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the 5-role matrix (owner, admin, reviewer, researcher, group-admin) has a completed UX baseline report (or an explicit blocker entry with evidence and unblock plan).
- **SC-002**: At least 90% of baseline P1/P2 UX defects have created tasks and assigned owners within one work cycle.
- **SC-003**: After improvements, at least 80% of test users complete 3 critical Workbench flows using only in-product cues, without external docs/help, and with no more than one failed attempt per flow.
- **SC-004**: Dead-end navigation states in test scenarios ("I do not know where to go next/how to go back") are reduced by at least 70% vs baseline.
- **SC-005**: The second Playwright pass leaves no unresolved P1 wayfinding/discoverability blockers.
- **SC-006**: 100% of baseline and rerun evidence artifacts are retained and retrievable for 90 days after each run.
- **SC-007**: Rerun is accepted only when all 5 roles complete the defined flows; any blocked role keeps rerun status in failed state.

## Wayfinding Quality Gates

The following gates define measurable acceptance thresholds for navigation quality:

- `first_click_success_rate`:
  - Definition: percentage of critical-task runs where first click enters the correct section.
  - Threshold: `>= 80%` per role in rerun evidence set.
- `backtrack_clarity_score`:
  - Definition: percentage of deep-flow runs where users return to parent context without ambiguity.
  - Threshold: `>= 85%` across required role matrix.
- `dead_end_rate`:
  - Definition: percentage of tested flows ending without a clear next action or return path.
  - Threshold: `<= 10%` and at least `70%` reduction vs baseline.
- `three_click_discoverability`:
  - Definition: percentage of critical destinations reached in three clicks or fewer from home.
  - Threshold: `>= 90%` across required roles.
