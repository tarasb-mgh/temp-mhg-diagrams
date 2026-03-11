# Feature Specification: Fix Tester-Tag User Listing Failure

**Feature Branch**: `001-fix-tester-tags-users`  
**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692) (Workbench tester tag assignment UI)  
**Jira Bug**: [MTB-703](https://mentalhelpglobal.atlassian.net/browse/MTB-703)  
**Created**: 2026-03-11  
**Status**: Ready for Implementation  
**Jira US1**: [MTB-704](https://mentalhelpglobal.atlassian.net/browse/MTB-704) | **Jira US2**: [MTB-705](https://mentalhelpglobal.atlassian.net/browse/MTB-705)  
**Input**: User description: "/speckit.specify bugfix https://api.workbench.dev.mentalhelp.chat/api/admin/tester-tags/users Request Method GET Status Code 500 Internal Server Error { \"success\": false, \"error\": { \"code\": \"INTERNAL_ERROR\", \"message\": \"Failed to list tester-tag users\" } } When https://workbench.dev.mentalhelp.chat/workbench/users/tester-tags On UI owner see error \"Failed to list tester-tag users\""

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open Tester Tag Management Without Failure (Priority: P1)

As an owner, I can open the tester-tag management page and see the list of users instead of a generic failure message.

**Why this priority**: The page is currently blocked for an authorized user, which prevents tester-tag administration entirely.

**Independent Test**: Can be fully tested by signing in as an owner, opening the tester-tag management page, and confirming the user list loads successfully without an internal error banner.

**Acceptance Scenarios**:

1. **Given** an owner has access to tester-tag management, **When** they open the tester-tag management page, **Then** the page displays a list of users and does not display a generic internal error message.
2. **Given** an owner refreshes the tester-tag management page, **When** the page reloads, **Then** the same authorized request completes successfully and the page remains usable.

---

### User Story 2 - Preserve Visible Tester-Tag State For Management Decisions (Priority: P2)

As an authorized workbench user, I can see each listed user's tester-tag state and eligibility information so I can make the correct management decision.

**Why this priority**: The page is only useful if it shows the same management data needed to assign or remove tester-tag access.

**Independent Test**: Can be fully tested by opening the page as an authorized user and confirming each visible row shows the user identity and current tester-tag state, with eligibility information available for the selected user.

**Acceptance Scenarios**:

1. **Given** the tester-tag management page loads successfully, **When** an authorized user reviews the list, **Then** each listed user shows current tester-tag state.
2. **Given** an authorized user selects a listed person, **When** the details panel opens, **Then** the page shows that person's current tester-tag eligibility and assignment status.

---

### Edge Cases

- What happens when no users match the current tester-tag filters? The page should show an empty-state message rather than a failure state.
- How does the system handle an authorized user opening the page when some users are ineligible for tester-tag access? The page should still load and clearly distinguish ineligible users from eligible users.
- How does the system handle temporary data retrieval problems? The page should present a clear user-facing error state without exposing internal failure details.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow authorized tester-tag managers, including owners, to open the tester-tag management page without receiving a generic internal failure for user-list retrieval.
- **FR-002**: The system MUST return the tester-tag user list for authorized requests whenever the underlying data needed for tester-tag management is available. A prerequisite for this is that the `tester` tag definition row exists in the database (seeded by migration `032_seed_tester_tag_definition.sql`).
- **FR-003**: The system MUST present each listed user with enough visible information to support tester-tag management, including identity and current tester-tag assignment state.
- **FR-004**: The system MUST preserve eligibility visibility for the selected user so authorized managers can distinguish eligible and ineligible accounts.
- **FR-005**: The system MUST show an empty-state message instead of an error when the current filters produce no matching users.
- **FR-006**: The system MUST show a clear user-facing failure state when user-list retrieval cannot be completed, and that failure state MUST avoid exposing internal system details.
- **FR-007**: The system MUST behave consistently for all roles already authorized to manage tester tags, without excluding owner access.

### Key Entities *(include if feature involves data)*

- **Tester-Tag User List Entry**: A visible management record representing a user who may appear in tester-tag management, including identity, current tester-tag state, and list-level eligibility summary.
- **Tester-Tag Status Detail**: The selected-user view that shows whether tester-tag access is assigned and whether the user is eligible for that access.
- **User-List Retrieval Failure State**: The user-facing state shown when the tester-tag list cannot be loaded, including a safe message for authorized managers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of authorized owner visits to the tester-tag management page complete without the current generic "Failed to list tester-tag users" error during validation of this fix.
- **SC-002**: Authorized tester-tag managers can load the tester-tag management page and view at least one valid user-list response on first attempt in the dev environment.
- **SC-003**: When no matching users exist for the current filter, the page shows an empty-state message instead of an internal error in 100% of validation scenarios.
- **SC-004**: When data retrieval genuinely fails, the page shows a safe, user-facing failure state without exposing internal system details in 100% of validation scenarios.

## Clarifications

### Session 2026-03-11

- Q: When `tag_definitions` is missing the `tester` tag row, which script must be run? → A: A new migration `032_seed_tester_tag_definition.sql` must be created and applied. Migration `015_add_tagging_system.sql` created the table and seeded `functional QA` and `short` rows but did not seed a `tester` row. Because `015` has already been applied on all environments, a new numbered migration with an idempotent `INSERT ... ON CONFLICT DO NOTHING` is the correct fix path. Applying `015` again would be a no-op for the tables but would not insert the missing row.

## Assumptions

- Existing tester-tag permissions already define which workbench roles may access the page; this bugfix restores correct behavior for those authorized roles rather than expanding scope.
- The intended tester-tag management experience remains the dedicated management page, with read-only tester-tag visibility elsewhere where already specified.
- The primary scope is fixing the failed user-list retrieval and preserving the expected management data shown on that page.
- The missing `tester` tag definition is the confirmed root cause of the 500 error. Migration `015_add_tagging_system.sql` is already applied in all environments and does not include this row. A new migration `032_seed_tester_tag_definition.sql` is needed to insert it idempotently.
