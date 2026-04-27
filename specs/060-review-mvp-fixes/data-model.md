# Data Model: Review MVP Defect Bundle

**Phase 1 output for `060-review-mvp-fixes`** | **Date**: 2026-04-27

This feature touches three data-shape concerns: (1) Session schema gains a typed broken-reason column; (2) BrokenReason is a new enum surfaced at the API and UI layers; (3) the Team Dashboard membership response shape gains a discriminator field.

---

## Entity 1: Session (existing — modified)

A chat conversation under review. **Existing entity**, schema changes are additive only.

### Fields (after this fix)

| Field | Type | Nullable | Default | Notes |
|-------|------|----------|---------|-------|
| `id` | UUID | NO | gen_random_uuid() | Primary key (existing) |
| `chat_id` | TEXT | NO | — | Existing FK / external chat reference |
| `status` | TEXT | NO | — | Existing: `pending`, `flagged`, `in_progress`, `completed`, `excluded` (and sub-statuses `unfinished`, `repeat`) |
| `group_id` | UUID | NO | — | Existing: Space the session belongs to (drives queue scoping) |
| `is_broken` | BOOLEAN | YES | false | **Existing** — broken flag (legacy NULL = not broken) |
| `broken_reason` | TEXT | YES | NULL | **NEW** — typed reason; CHECK constraint enumerates allowed values + NULL |
| `created_at` | TIMESTAMPTZ | NO | now() | Existing |
| ... | | | | (other existing fields not touched) |

### New CHECK constraint

```sql
ALTER TABLE sessions
  ADD CONSTRAINT broken_reason_valid
  CHECK (broken_reason IS NULL OR broken_reason IN (
    'NO_ASSISTANT_REPLIES',
    'EMPTY_TRANSCRIPT',
    'MALFORMED',
    'UNKNOWN'
  ));
```

### Validation rules (FR ↔ data)

- **FR-009**: When `is_broken = true`, `broken_reason` SHOULD be set (one of the enum members or `UNKNOWN`). When `is_broken = false`, `broken_reason` MUST be NULL.
- **FR-011**: Each broken-detection criterion writes the reason matching its intent (verified by unit tests on `broken-detection.service.ts`).
- Legacy rows: rows existing before the migration have `broken_reason = NULL` even when `is_broken = true`; the UI fallback (FR-012) renders the `UNKNOWN` tooltip copy.

### State transitions

No new state transitions. The `is_broken` flag was already set during ingest/processing. The new column is set in the same code path.

---

## Entity 2: BrokenReason (new — enum)

Categorical reason a session was flagged broken. Surfaced at three layers: DB CHECK constraint, TypeScript enum in `chat-backend` types, and i18n string keys in `workbench-frontend`.

### Members

| Code | Meaning | Example trigger |
|------|---------|-----------------|
| `NO_ASSISTANT_REPLIES` | Session contains user messages but zero assistant responses to rate. | Detected when `assistant_message_count == 0`. |
| `EMPTY_TRANSCRIPT` | Session has no messages at all (neither user nor assistant). | Detected when `total_message_count == 0`. |
| `MALFORMED` | Session metadata is structurally broken (corrupted JSON, missing required fields, schema mismatch). | Detected by validation against the session schema during ingest. |
| `UNKNOWN` | Reason not deterministically inferable; legacy row or new criterion not yet codified. | Fallback for pre-migration broken rows. |

### Surface mapping

- **DB**: TEXT column with CHECK constraint (above).
- **TypeScript** (`chat-backend/src/types/review.ts`): `export type BrokenReason = 'NO_ASSISTANT_REPLIES' | 'EMPTY_TRANSCRIPT' | 'MALFORMED' | 'UNKNOWN';`
- **DTO** (Session response): `brokenReason: BrokenReason | null`.
- **i18n** (`workbench-frontend/src/i18n/{lang}/review.json`):
  - `brokenReason.NO_ASSISTANT_REPLIES`: "This session has no assistant replies to rate."
  - `brokenReason.EMPTY_TRANSCRIPT`: "This session's transcript is empty."
  - `brokenReason.MALFORMED`: "This session's data is malformed."
  - `brokenReason.UNKNOWN`: "This session was flagged as not reviewable."
  - (Plus uk/ru translations of the same keys.)

### Extensibility

Adding a new reason requires:
1. New value in DB CHECK constraint (migration).
2. New member in TypeScript enum.
3. New i18n key in en/uk/ru.
4. New criterion in `broken-detection.service.ts` writing this reason.

This is enumerated in CONTRIBUTING-style documentation that lives near the broken-detection service (out of scope for this fix; will be added incidentally).

---

## Entity 3: TeamMembership response (new — DTO shape)

Shape of the response returned by `GET /api/team-dashboard/membership`. Used by the workbench-frontend Team Dashboard to decide whether to render content or an empty state.

### Shape

```ts
type TeamMembershipResponse = {
  spaces: Space[];                    // Spaces the user belongs to (matches Space-combobox source)
  hasTeamMembership: boolean;         // True if the user meets the team-member role requirement
  missingRole: string | null;         // When hasTeamMembership=false AND user has spaces, names the missing role; null otherwise
};

type Space = {
  id: string;
  name: string;
  // ... other existing Space fields not touched
};
```

### Field semantics

- `spaces`: returned via the same `getSpacesForUser(userId)` source as the Space combobox endpoint. The two endpoints MUST never disagree about Space membership (FR-013).
- `hasTeamMembership`:
  - `true` when the user has at least one Space AND meets any role requirement for Team Dashboard (for this fix: Owner role implicitly meets it).
  - `false` when the user has zero Spaces, OR has Spaces but lacks the team-member role (when such a role is enforced in the future).
- `missingRole`:
  - `null` when `hasTeamMembership = true` (no missing role; render content).
  - `null` when `hasTeamMembership = false AND spaces.length === 0` (render generic "no Spaces" empty state).
  - Non-null string (e.g., `"reviewer-team-member"`) when `hasTeamMembership = false AND spaces.length > 0` (render specific empty-state copy referencing the missing role).

### Frontend rendering decision tree

```text
fetch /api/team-dashboard/membership
  ↓
hasTeamMembership === true?
  ├── YES → render Team Dashboard content (statistics, charts)
  └── NO  → missingRole !== null?
              ├── YES → render "Team Dashboard requires {missingRole}; ask admin"
              └── NO  → render "You are not a member of any Space" (legitimate empty state)
```

### Validation rules (FR ↔ data)

- **FR-013**: `spaces` field comes from the same source as the Space-combobox endpoint. Verified by the integration test that compares the two endpoints' Space lists.
- **FR-014**: Owner role with ≥1 Space membership returns `hasTeamMembership: true, missingRole: null`.
- **FR-015**: When `hasTeamMembership: false AND spaces.length > 0`, `missingRole` MUST be non-null.
- **FR-016**: When `spaces.length === 0`, `hasTeamMembership: false, missingRole: null`.

---

## Migration plan

### `060_broken_reason_column.sql`

Single forward migration; no separate backfill migration.

```sql
-- Add nullable column
ALTER TABLE sessions
  ADD COLUMN broken_reason TEXT NULL;

-- Constrain to enum values + NULL
ALTER TABLE sessions
  ADD CONSTRAINT broken_reason_valid
  CHECK (broken_reason IS NULL OR broken_reason IN (
    'NO_ASSISTANT_REPLIES',
    'EMPTY_TRANSCRIPT',
    'MALFORMED',
    'UNKNOWN'
  ));

-- Index for queue queries that filter by is_broken AND/OR broken_reason
CREATE INDEX IF NOT EXISTS idx_sessions_is_broken
  ON sessions (is_broken)
  WHERE is_broken = true;
```

**Notes**:
- Migration is forward-only and additive. No rollback script needed (the column can be dropped by a follow-up migration if desired; data loss is the dropped reasons only).
- Index is partial (only rows with `is_broken = true`) to keep the index small (broken sessions are rare).
- No backfill in this migration. A separate one-off backfill script MAY be authored later if the typed reasons need to be inferred for legacy rows; out of scope for this release.

### Forward compatibility

- chat-backend code paths reading `session.broken_reason` MUST handle NULL gracefully (treat as `UNKNOWN`).
- workbench-frontend code paths reading `session.brokenReason` MUST handle `undefined` / `null` gracefully (fallback to `brokenReason.UNKNOWN` i18n key).

---

## Data flow

```
Detection (chat-backend ingest path)
  ├── Criterion fires → write { is_broken: true, broken_reason: <typed> }
  └── No criterion fires → leave is_broken at false (broken_reason stays NULL)

Read (Reviewer queue)
  GET /api/review/queue?...&include_broken=false (default)
    ↓
  reviewQueueService.listBy({ ...filters, isBroken: false })
    ↓
  SELECT ... FROM sessions WHERE is_broken = false AND <other filters>
    ↓
  Response excludes broken sessions

Read (Dashboard counter)
  GET /api/dashboard/summary?groupId=<active>
    ↓
  reviewQueueService.countBy({ groupId, statuses: ['pending'], isBroken: false })
    ↓
  SELECT count(*) FROM sessions WHERE status = 'pending' AND is_broken = false AND group_id = <active>
    ↓
  Tile shows count

Read (Team Dashboard)
  GET /api/team-dashboard/membership
    ↓
  teamMembershipService.getMembership(userId)
    ↓
    ├── getSpacesForUser(userId) [same source as Space combobox]
    ├── checkTeamMemberRole(userId) [returns missingRole | null]
    └── return { spaces, hasTeamMembership, missingRole }
```

---

## Summary

| Entity | Status | Schema change | Surface |
|--------|--------|---------------|---------|
| Session | existing → modified | + `broken_reason TEXT NULL` column | DB, DTO |
| BrokenReason | new (enum) | CHECK constraint values | DB, TS type, DTO, i18n |
| TeamMembership response | new (DTO) | `{ spaces, hasTeamMembership, missingRole }` | API response |

All entities map directly to the spec's Key Entities section (Session, BrokenReason, TeamMembership response) with concrete field types and validation rules.
