# Research: Survey Instance Management (029)

**Branch**: `029-survey-management` | **Date**: 2026-03-14

## Decision Log

---

### D-001: PATCH endpoint vs. new status-change endpoints for instance edits

**Decision**: Add `PATCH /survey-instances/:id` accepting `expirationDate?` and `groupIds?` as separate optional fields, validated independently.

**Rationale**: The existing pattern in `survey.instances.ts` uses dedicated POST endpoints for state transitions (close, invalidate) and POST for creation. A single PATCH for editable metadata fields (expiration date, group assignment) is consistent with how the schema routes handle `PUT/PATCH /survey-schemas/:id`. Separate endpoints per field would add route proliferation for minor ops.

**Alternatives considered**:
- Separate `PATCH /survey-instances/:id/expiration` and `PATCH /survey-instances/:id/groups` — rejected: unnecessary granularity; no security reason to split these.
- PUT (full replacement) — rejected: existing fields like `schema_snapshot`, `status`, `add_to_memory` should not be overwritable by an edit form.

---

### D-002: Expiration date update and re-activation of expired instances

**Decision**: When `expirationDate` is updated to a future value on an instance with `status='expired'`, the service MUST reset `status` back to `'active'` in the same UPDATE statement. If the instance was `status='draft'`, only the date is updated (draft instances activate via inline check on gate-check).

**Rationale**: The spec's success criteria say "the survey closes at the new earlier date" (active → update) and "users can still submit within the updated window" — which only makes sense if an expired instance can be revived. Keeping `status='expired'` after extending the date would break the gate-check inline transition logic (it only transitions `draft→active` and `active→expired`, not `expired→active`).

**Constraint preserved**: New `expirationDate` MUST be strictly after `now()`. The existing DB constraint `expiration_date > start_date` is also still respected.

**Alternatives considered**:
- Only allow expiration changes on `status='active'` instances — rejected: the user description says "change mid-flight" broadly; re-activating an accidentally-expired survey is a natural use case.
- Allow setting expiration to past dates to forcibly expire — rejected: explicit close endpoint (`POST /survey-instances/:id/close`) already handles deliberate closure.

---

### D-003: Group assignment change semantics — replace vs. add

**Decision**: `PATCH /survey-instances/:id` with `groupIds` replaces the entire `group_ids` array. The `group_survey_order` table is updated to add rows for new groups and remove rows for groups no longer in the list. Existing `survey_responses` rows are **never deleted** regardless of group changes.

**Rationale**: The spec explicitly states "completed surveys are preserved." Responses are stored with their `group_id` at time of submission — they remain valid historical records. The `group_ids` array controls which groups are *currently* eligible, not which groups have historical data.

**group_survey_order sync**: New groups get a `group_survey_order` row inserted (with `display_order` = max existing + 1 for the group). Removed groups have their `group_survey_order` row deleted (since the survey is no longer assigned to them — ordering is meaningless).

**Alternatives considered**:
- Keep group_survey_order rows for removed groups — rejected: the `GET /groups/:groupId/surveys` endpoint would continue showing a removed-group survey, which is incorrect.
- Also preserve group_survey_order for removed groups as "archived" — rejected: over-engineering; no UI requirement for this.

---

### D-004: Statistics endpoint — per-group vs. aggregate

**Decision**: `GET /survey-instances/:id/statistics` returns an array of per-group statistics objects (one per group in `group_ids`). Each object contains the total member count, completion count, pending count, completion rate, and the **list of non-completers** for that group.

**Rationale**: The spec says "identify the group users who have not completed." Since an instance can span multiple groups (`group_ids[]`), a flat aggregate would hide which group each non-completer belongs to. Per-group breakdown matches the multi-group model already present in the backend.

**Alternatives considered**:
- Single aggregate across all groups — rejected: non-completers from different groups would be mixed, reducing actionability.
- Optional `?groupId=` filter — accepted as an additive option: the endpoint returns all-groups by default; an optional `groupId` query param filters to a single group for efficiency.

---

### D-005: Non-completer user identity in statistics

**Decision**: The statistics query will JOIN `group_memberships → users` to get `user_id`, `display_name`, and `email`. The response will return `userId` (UUID), `displayName`, and `isComplete` (boolean). `email` is included for workbench use (admin context, privacy-aware).

**Rationale**: `survey_responses.pseudonymous_id` is the user's UUID (verified from gate-check logic: the auth layer passes `req.user.id` as `pseudonymousId` in the response submission flow). Therefore a direct equality JOIN between `group_memberships.user_id` and `survey_responses.pseudonymous_id` is valid.

**Privacy note**: The statistics endpoint is gated by `SURVEY_INSTANCE_MANAGE | SURVEY_INSTANCE_VIEW` — workbench-only, authentication required.

**Alternatives considered**:
- Return only `pseudonymousId` without display name — rejected: unusable for follow-up; workbench admins need to identify people by name.
- Return hashed identifiers — rejected: this is a workbench admin feature, not a public-facing endpoint; full identity is appropriate.

---

### D-006: New types needed in chat-types

**Decision**: Add the following to `chat-types`:
- `SurveyInstanceUpdateInput`: `{ expirationDate?: string; groupIds?: string[] }`
- `SurveyMemberCompletion`: `{ userId: string; displayName: string; email: string; isComplete: boolean; completedAt: string | null }`
- `SurveyGroupStatistics`: `{ groupId: string; groupName: string; totalMembers: number; completedCount: number; pendingCount: number; completionRate: number; nonCompleters: SurveyMemberCompletion[] }`
- `SurveyInstanceStatistics`: `{ instanceId: string; groups: SurveyGroupStatistics[] }`

**Rationale**: New response shape for the statistics endpoint needs shared types between backend and workbench-frontend. Consistent with existing patterns in `survey.ts`.

---

### D-007: No database migration required

**Decision**: No new migration needed. All fields required by this feature exist in the current schema.

**Rationale**:
- Expiration date update: `UPDATE survey_instances SET expiration_date = $1, updated_at = now() WHERE id = $2`
- Group IDs update: `UPDATE survey_instances SET group_ids = $1::uuid[], updated_at = now() WHERE id = $2`
- Status re-activation: included in the same UPDATE via conditional logic in the service
- Statistics: achieved via SQL JOIN across `users`, `group_memberships`, and `survey_responses`
- `group_survey_order` INSERT/DELETE: already supported by existing table structure

---

### D-008: No chat-frontend changes required

**Decision**: The chat-frontend (end-user chat UI) is not modified. This feature is entirely workbench-admin functionality.

**Rationale**: Changes to expiration date and group assignment are admin operations in the workbench. The existing gate-check mechanism on the chat side will naturally reflect the updated expiration date and group list when users next call `GET /survey/gate-check`.
