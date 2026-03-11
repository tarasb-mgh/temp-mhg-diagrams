# Phase 0 Research: Workbench Tester Tag Assignment UI

## Decision 1: Reuse the Existing Tagging Model

**Decision**: Reuse the existing user-tag model introduced by `010-chat-review-tagging` and treat `tester` as an existing predefined user-level tag.

**Rationale**: The feature is about management UI, not about redefining the tagging domain. Reusing the existing model avoids duplicate storage concepts and keeps `024` aligned with `023`, which already depends on tester-tag presence rather than a separate flag.

**Alternatives considered**:
- Create a dedicated boolean field like `isTester` on the user record: rejected because it duplicates an existing tag-based capability and creates drift with the broader tagging model.
- Introduce a second tester-specific table: rejected because it adds persistence complexity without adding business value.

## Decision 2: Use a Dedicated Management Page Instead of Inline Profile Editing

**Decision**: Manage tester-tag assignment and removal only from a dedicated workbench page, while keeping the user profile read-only for tester status.

**Rationale**: The `tester` tag enables internal diagnostic behavior, so the management surface should be narrowly scoped and easier to permission-gate. Profile visibility remains useful for awareness, but edit controls on profile pages would broaden accidental access and blur the distinction between viewing and managing.

**Alternatives considered**:
- Edit directly from the user profile: rejected because the user explicitly clarified that management must happen elsewhere.
- Use a global generic tag-management page only: rejected because this release is intentionally scoped to the `tester` tag first.

## Decision 3: Restrict Access to Admin, Supervisor, and Owner

**Decision**: Only `Admin`, `Supervisor`, and `Owner` can access the dedicated tester-tag management page and perform changes.

**Rationale**: This is a sensitive internal-use tag that changes diagnostic visibility in chat. Restricting page access entirely is simpler and safer than mixing read-only and editable states for broader roles on the same page.

**Alternatives considered**:
- Allow broader read-only access to the dedicated page: rejected because read-only visibility is already satisfied on user profiles.
- Allow reviewer-level access with hidden edit controls: rejected because it increases navigation and authorization complexity without operational value.

## Decision 4: Enforce Eligibility on the Backend

**Decision**: The backend must validate that only eligible internal staff or dedicated test accounts can receive the `tester` tag.

**Rationale**: UI checks alone are insufficient for a sensitive authorization-related feature. Backend validation ensures the rule still holds if requests are replayed, automated, or sent outside the intended workbench UI.

**Alternatives considered**:
- Frontend-only blocking: rejected because it is bypassable and would not satisfy the safety intent of the feature.
- Permit assignment with warning only: rejected because the clarified spec explicitly requires blocking regular end-user accounts.

## Decision 5: Expose a Narrow Dedicated API Contract

**Decision**: Add dedicated backend endpoints for reading tester-tag eligibility/status and for updating tester-tag assignment state, instead of wiring the page directly to a generic tag-CRUD surface.

**Rationale**: The page has a narrow purpose, so a focused contract is easier to secure, easier to test, and less likely to leak unrelated tag-management capabilities into this release. It also supports the future-expansion requirement by defining a clean management flow now.

**Alternatives considered**:
- Reuse a broad generic tag-management API for all user tags: rejected because this release is intentionally scoped to one tag and would inherit unnecessary complexity.
- No dedicated read endpoint, only a blind update endpoint: rejected because the page needs current state and eligibility to render clearly and safely.

## Decision 6: Preserve Read-Only Tester Visibility on User Profiles

**Decision**: Any workbench user who can access a user profile can see whether the `tester` tag is assigned, but cannot modify it there.

**Rationale**: Visibility supports QA, support, and operational awareness without increasing edit surface area. This also keeps the management workflow centralized while preserving transparency in the profile view.

**Alternatives considered**:
- Hide tester status except from managers: rejected because the clarified spec explicitly requires profile visibility.
- Show an edit affordance on profile with redirect: rejected because it complicates the read-only boundary unnecessarily.

## Decision 7: Keep the Release Tester-Focused but Expansion-Friendly

**Decision**: The page manages only the `tester` tag in this release, but its naming, layout, and backend contract should be shaped so additional user tags can be supported later without replacing the workflow.

**Rationale**: This preserves a tight MVP while reducing rework when the team later expands dedicated user-tag management. It fits the spec clarification that future expansion matters, but does not justify general-tag UI in this release.

**Alternatives considered**:
- Build a full user-tag management console now: rejected because it expands scope beyond the approved feature.
- Hardcode a one-off tester-only flow with no reusable structure: rejected because the clarified spec explicitly requests future expansion compatibility.
