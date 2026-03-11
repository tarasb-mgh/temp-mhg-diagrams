# Feature Specification: Workbench Tester Tag Assignment UI

**Feature Branch**: `024-tester-tag-workbench`  
**Created**: 2026-03-11  
**Status**: Draft  
**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692)  
**Input**: User description: "UI for workbench where this tester tag could be assign to user by admin/supervisor/owner"

**Related Specs**:
- `010-chat-review-tagging` — Existing user and chat tagging capability, including user tag assignment
- `011-chat-review-supervision` — Defines RAG details in chat for tester-tagged users
- `023-fix-rag-panel-visibility` — Clarifies tester-tag visibility behavior for chat RAG details

## Clarifications

### Session 2026-03-11

- Q: Should the workbench block assigning the `tester` tag to regular end-user accounts? → A: Yes. Block assignment for regular end-user accounts; only eligible internal or dedicated test accounts can receive the `tester` tag.
- Q: Where should the `tester` tag be managed in the workbench? → A: The `tester` tag can be managed only from a dedicated tag-management page, not from the user profile. The user profile must still show the tag visibly to everyone who has access to that page.
- Q: Should the dedicated page manage only the `tester` tag, all user tags, or just `tester` now with future expansion in mind? → A: Manage `tester` now, but explicitly design the page for future expansion to more user tags.
- Q: Who can access the dedicated tester tag-management page? → A: Only `Admin`, `Supervisor`, and `Owner` can access the dedicated tag-management page.
- Q: What audit information must be recorded when the tester tag is assigned or removed? → A: Log assign/remove with actor, target user, previous state, new state, timestamp, and success/failure result.
- Q: What must the security review cover for this feature? → A: Security review must cover page access control, backend authorization, end-user eligibility blocking, and audit logging.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Assign Tester Tag From Dedicated Management Page (Priority: P1)

An admin, supervisor, or owner opens a dedicated tag-management page in the workbench and can assign the `tester` tag to an eligible internal staff account or dedicated test account. Regular end-user accounts cannot receive the `tester` tag from this UI. Once assigned, the user is clearly marked as a tester in the workbench, and future chat sessions accessed by that user can surface tester-only technical details such as RAG sources where allowed by policy. The user profile itself shows the assigned `tester` tag as visible status, but does not provide the control to change it. This page manages the `tester` tag in this feature release, while being structured so additional user tags can be added later without redefining the workflow.

**Why this priority**: Without a visible workbench control for assigning the tester tag, the tester-only experience depends on manual backend changes or hidden tooling. This blocks QA and internal validation workflows.

**Independent Test**: Can be fully tested by opening the dedicated tag-management page as an admin, supervisor, or owner, assigning the `tester` tag, saving the change, and verifying the tag is shown on the related user profile and persists after reload.

**Acceptance Scenarios**:

1. **Given** an admin, supervisor, or owner viewing an eligible user on the dedicated tag-management page, **When** they assign the `tester` tag and save, **Then** the tag is stored and displayed on the related user profile.
2. **Given** a user profile that already has the `tester` tag, **When** the workbench loads the profile, **Then** the tag is visibly shown as already assigned to any workbench user who can access that profile.
3. **Given** an eligible internal user without the `tester` tag, **When** an authorized role adds it, **Then** future sessions accessed by that user are treated as tester-tagged for tester-only UI behavior.
4. **Given** a workbench user viewing a user profile, **When** the profile is displayed, **Then** they can see whether the `tester` tag is assigned if they have access to that profile, but they cannot change it from that page.
5. **Given** a role other than `Admin`, `Supervisor`, or `Owner`, **When** they navigate through the workbench, **Then** they do not get access to the dedicated tester tag-management page.
6. **Given** an admin, supervisor, or owner viewing a regular end-user account on the dedicated tag-management page, **When** they attempt to assign the `tester` tag, **Then** the workbench blocks the action and explains that only eligible internal or dedicated test accounts can receive the tag.

---

### User Story 2 - Remove Tester Tag From Dedicated Management Page (Priority: P1)

An admin, supervisor, or owner can remove the `tester` tag from a user on the same dedicated tag-management page. Once removed, the workbench no longer shows the user as a tester on their profile, and future sessions accessed by that user no longer receive tester-only chat visibility.

**Why this priority**: Tag removal is required to keep tester access accurate over time. Without a removal path, temporary test access becomes sticky and can expose technical diagnostics longer than intended.

**Independent Test**: Can be tested by opening the dedicated tag-management page for a tester-tagged user, removing the `tester` tag as an authorized role, saving, and verifying the tag no longer appears on the user profile after reload.

**Acceptance Scenarios**:

1. **Given** an admin, supervisor, or owner viewing a user on the dedicated tag-management page who already has the `tester` tag, **When** they remove the tag and save, **Then** the tag is removed from the related user profile.
2. **Given** a user whose `tester` tag was removed, **When** they access future chat sessions, **Then** tester-only technical details are no longer shown in chat.
3. **Given** a user profile without the `tester` tag, **When** the profile is displayed, **Then** the UI clearly indicates that the user is not currently marked as a tester.

---

### User Story 3 - Safe And Understandable Tester Tag Management (Priority: P2)

The workbench makes tester-tag assignment understandable and safe for authorized roles. The dedicated tag-management page shows that the `tester` tag is intended for internal staff and dedicated test accounts only. The UI helps authorized users avoid assigning the tag to regular end users by mistake and makes the current tag state easy to review. User profiles display the current `tester` tag state as visible status for anyone who can access the profile. The page is intentionally scoped to `tester` in this release, but its workflow and terminology should support future expansion to additional user tags.

**Why this priority**: The `tester` tag unlocks technical diagnostic visibility, so the management UI must communicate its purpose clearly and reduce accidental misuse.

**Independent Test**: Can be tested by viewing the tester tag control on eligible and ineligible user accounts and verifying the workbench provides clear status and guidance about who should receive the tag.

**Acceptance Scenarios**:

1. **Given** an authorized role viewing the dedicated tester tag-management page, **When** they inspect the UI, **Then** they see plain-language guidance that the tag is intended only for internal staff or dedicated test accounts.
2. **Given** an authorized role viewing a regular end-user account in the dedicated tag-management page, **When** they inspect the tester tag control, **Then** the UI clearly indicates that the tester tag cannot be assigned to that account because it is reserved for internal testing use only.
3. **Given** the tester tag is already assigned, **When** any workbench user with access views the profile, **Then** the UI clearly indicates the current tester status without requiring additional navigation.

---

### Edge Cases

- What happens when two authorized users edit the same tester-tag assignment at the same time from the dedicated management page? The last saved tester-tag change becomes the current state, and the workbench reflects the final saved value after refresh.
- What happens when an authorized user attempts to assign the `tester` tag to a regular end-user account? The workbench blocks the action and shows a clear message that only eligible internal staff or dedicated test accounts can receive the tag.
- What happens when the `tester` tag already exists on the user from another management path? The workbench loads and displays the existing state without duplicating the tag, and the user profile reflects the same current status.
- What happens when a user loses the `tester` tag while actively viewing a chat? The updated tag state applies on the next relevant data refresh or next session load.
- What happens when the save action fails? The workbench keeps the previous visible state and shows a clear error message that the tester-tag update was not saved.
- What happens if a caller bypasses the workbench UI and attempts to assign the `tester` tag directly through a backend request? Backend authorization and eligibility validation still block the request, and the failed attempt is audit-logged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a dedicated workbench tag-management page where authorized roles can assign or remove the `tester` tag for a user.
- **FR-002**: System MUST allow `Admin`, `Supervisor`, and `Owner` roles to assign the `tester` tag to a user from the dedicated tag-management page.
- **FR-003**: System MUST allow `Admin`, `Supervisor`, and `Owner` roles to remove the `tester` tag from a user from the dedicated tag-management page.
- **FR-004**: System MUST prevent unauthorized roles from assigning or removing the `tester` tag in the workbench UI.
- **FR-004a**: System MUST allow only `Admin`, `Supervisor`, and `Owner` roles to access the dedicated tester tag-management page.
- **FR-005**: System MUST persist tester-tag assignment changes so the updated state remains visible after page reload.
- **FR-006**: System MUST show the current tester-tag state on the user profile in a way that is immediately visible to any workbench user who can access that profile.
- **FR-007**: System MUST display plain-language guidance in the dedicated tag-management page that the `tester` tag is intended for internal staff and dedicated test accounts.
- **FR-008**: System MUST show a warning or caution message on the dedicated tag-management page when an authorized user is assigning the `tester` tag to make clear that it enables tester-only technical visibility in chat.
- **FR-008a**: System MUST block assignment of the `tester` tag to regular end-user accounts in the workbench UI.
- **FR-009**: System MUST ensure future chat access by tester-tagged users follows existing tester-tag behavior already defined in related specifications.
- **FR-010**: System MUST avoid creating duplicate `tester` tag assignments on the same user account.
- **FR-011**: System MUST preserve the previous visible state and show an error message if a tester-tag assignment or removal attempt fails to save.
- **FR-012**: System MUST NOT allow assigning or removing the `tester` tag directly from the user profile page.
- **FR-013**: System MUST scope the dedicated page to managing the `tester` tag in this release while keeping page language and workflow compatible with future expansion to additional user tags.
- **FR-014**: System MUST audit-log every tester-tag assignment and removal attempt with actor identity, target user, previous state, new state, timestamp, and success/failure result.
- **FR-015**: System MUST complete a security review for the feature covering dedicated-page access control, backend authorization enforcement, end-user eligibility blocking, and tester-tag audit logging before release readiness.

### Key Entities *(include if feature involves data)*

- **Tester Tag**: A user-level tag that marks a user as eligible to see tester-only technical chat details. Key attributes: tag name, assigned/not-assigned state, assignment timestamp, assigned-by reference, eligibility limited to internal staff or dedicated test accounts.
- **Tester Tag Management Page**: A dedicated workbench page for viewing and changing tester-tag status on user accounts. Key attributes: current tester state, eligibility status, authorization visibility, warning text, save result state, future-expandable workflow for additional user tags.
- **User Profile Tester Status**: A visible status indicator on the user profile showing whether the `tester` tag is assigned. Key attributes: current tester state, read-only visibility, profile display context.
- **Authorized Tag Manager**: A workbench user with permission to manage the tester tag. Key attributes: role, ability to assign/remove tag, audit accountability for the change.
- **Tester Tag Audit Record**: A record of a tester-tag assignment or removal attempt. Key attributes: actor identity, target user identity, previous tester state, new tester state, timestamp, and success/failure result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of users who have the `tester` tag show that status correctly on their workbench profile.
- **SC-002**: 100% of successful tester-tag assignment and removal actions performed by `Admin`, `Supervisor`, or `Owner` are reflected on reload.
- **SC-003**: 0% of unauthorized users can change tester-tag state through the workbench UI.
- **SC-003a**: 0% of roles other than `Admin`, `Supervisor`, and `Owner` can access the dedicated tester tag-management page.
- **SC-004**: Authorized users can complete tester-tag assignment or removal in 30 seconds or less from the dedicated tag-management page.
- **SC-005**: 100% of failed tester-tag save attempts present a clear error message and leave the prior visible state unchanged.
- **SC-006**: 100% of tester-tag controls show guidance that the tag is for internal staff or dedicated test accounts only.
- **SC-007**: 0% of regular end-user accounts can receive the `tester` tag through the workbench UI.
- **SC-008**: 0% of tester-tag changes are performed directly from the user profile page; all successful changes originate from the dedicated tag-management page.
- **SC-009**: The dedicated tag-management page can add support for additional user tags later without requiring a separate replacement workflow for tester-tag management.

## Assumptions

- The `tester` tag already exists in the broader tagging model and does not need a new tag-definition workflow in this feature.
- A workbench user profile surface already exists and can display user-level tags, and a dedicated tag-management page can be added or extended for tester-tag changes.
- Existing authorization rules can distinguish `Admin`, `Supervisor`, and `Owner` from roles that should not manage the `tester` tag.
- Access to the dedicated tester tag-management page can be restricted to `Admin`, `Supervisor`, and `Owner` roles only.
- The system can distinguish eligible internal or dedicated test accounts from regular end-user accounts for the purpose of blocking invalid tester-tag assignment.
- Existing tester-tag behavior in chat remains unchanged by this feature; this feature adds a visible management UI rather than redefining chat visibility policy.
- This release manages only the `tester` tag, but the same page may later support additional user tags without replacing the tester-tag management flow.
- Tester-tag changes affect future relevant chat access after the next data refresh or session load rather than retroactively changing already-rendered UI without refresh.
- Tester-tag assignment and removal are treated as auditable admin operations and must be captured through the existing audit logging infrastructure.
- This feature requires an explicit security review covering page access, backend authorization, eligibility enforcement, and audit logging before release readiness.
