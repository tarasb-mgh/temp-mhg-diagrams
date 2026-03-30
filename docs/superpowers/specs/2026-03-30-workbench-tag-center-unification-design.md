# Workbench Tag Center Unification Design

**Date**: 2026-03-30  
**Input**: Unify tagging into a single Workbench Tag Center focused on clarity, control, and low-error workflows.

## One-Sentence Goal

Create a unified Workbench Tag Center that consolidates user-tag and review-tag workflows into a single entry point, standardizes capability-based authorization and backend tagging APIs, and improves operator UX with low-friction, low-error happy paths.

## Context

- Current tagging operations are split across:
  - `/workbench/review/tags` (review/chat tag management)
  - `/workbench/users/tester-tags` (special-case user tag assignment flow)
- `tester` must be treated as a standard user tag going forward.
- The UI must remain minimal, intuitive, and controllable while supporting secure operations.
- Capability-based permissions must be the single source of truth for both UI and API authorization.

## Design Decision

Introduce one Tag Center page with two clearly separated modes:

1. **User Tags**
   - Manage user tag definitions.
   - Assign and unassign user tags.
   - Search/filter users and tags.
   - Show all assigned tags in user profile.
2. **Review Tags**
   - Manage review/chat tag definitions.
   - Keep review-operations behavior clearly separated from user assignment behavior.

## Key Acceptance Criteria

1. **Single Entry Point**
   - Operators access one Tag Center location for all tagging workflows.
2. **Semantic Separation**
   - User tag workflows and review tag workflows are visibly separated in the UI.
3. **Capability-Based Authorization**
   - All page visibility and actions are gated by capabilities, not hardcoded role logic.
   - API authorization enforces the same capability model.
4. **Backend Unification**
   - Dedicated tester-tag API paths are deprecated and replaced with generic user-tag APIs.
   - `tester` behaves as a normal user tag definition and assignment.
5. **User Profile Visibility**
   - User profile displays all assigned user tags.
6. **No Legacy URL Requirement**
   - Legacy routes are not required to be preserved.
7. **Localization**
   - Strings are delivered with priority order English -> Ukrainian -> Russian.
8. **E2E Completeness**
   - Playwright E2E covers each key operation and permission/error scenario for user and review tag workflows.
9. **UX Quality Target**
   - Validation evidence shows streamlined happy paths and no more than 1-2 errors per happy flow.

## Candidate Information Architecture

- `Tag Center`
  - `User Tags` mode
    - Definitions
    - Assignments
    - Search/filter
  - `Review Tags` mode
    - Definitions

## Risks and Mitigations

- **Risk**: Overloading one screen with too many controls.  
  **Mitigation**: Mode separation with progressive disclosure and capability-based control visibility.
- **Risk**: Permission drift between frontend and backend.  
  **Mitigation**: Shared capability contract and E2E forbidden-action tests.
- **Risk**: Migration regressions for tester-tag behavior.  
  **Mitigation**: Data migration checks and backward-compatibility verification for existing assignments.

## Out of Scope

- Bulk assignment operations.
- Redirect support for legacy URLs.

## FEATURE_DESCRIPTION (for /speckit.specify)

Unify tagging into a single Workbench Tag Center with separate User Tags and Review Tags modes, standardized capability-based authorization, unified backend tagging APIs that treat `tester` as a normal user tag, full visibility of assigned user tags in user profiles, and complete Playwright E2E coverage for create/edit/archive/delete/assign/unassign/search/permission/error workflows while preserving a minimal, intuitive low-error UX.
