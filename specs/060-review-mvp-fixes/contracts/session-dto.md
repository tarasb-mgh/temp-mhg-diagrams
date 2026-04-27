# Contract: Session DTO additions

> ⚠️ **V1 DESIGN — ABANDONED.** This contract describes the v1 fix-bundle design (typed `BrokenReason` enum + `sessions.broken_reason` DB column + `brokenReason` DTO field) that was discarded after codebase inspection on 2026-04-27. The revised `spec.md` (US4 / FR-007 / Out-of-scope) explicitly notes that **none** of this is needed: the existing tooltip text in `workbench-frontend/src/locales/en.json:1459` is already accurate for the actual `isBroken` criterion, and US1's parity-guard extension (chat-backend `2baface`) filters broken sessions out of the queue before render so the tooltip is rarely seen. Kept here for speckit chain provenance only — see `../tasks.md` for what actually shipped.

---

**Feature**: `060-review-mvp-fixes` | **FR refs**: FR-009, FR-010, FR-012 *(v1 numbering — superseded)*

## Purpose

Document the session DTO field additions that flow from chat-backend → workbench-frontend, enabling the frontend to render the correct broken-reason tooltip without hardcoded strings.

## Affected response surfaces

The Session DTO is returned by multiple endpoints:
- `GET /api/review/queue` (list view; see `review-queue.md`)
- `GET /api/review/sessions/:id` (detail view)
- `GET /api/review/sessions/:id/...` (sub-resources may include the parent session)

All Session DTO instances MUST include the new fields described below.

## DTO shape (after this fix)

```ts
type SessionDTO = {
  // ... existing fields ...

  // === New / changed fields ===

  /** True if the system has flagged this session as not reviewable. */
  isBroken: boolean;

  /**
   * Typed reason describing WHY the session is broken.
   * Null when isBroken=false, OR when isBroken=true but reason was not recorded
   * (legacy rows pre-dating the typed-reason migration).
   * Frontend MUST handle null by falling back to the UNKNOWN reason copy.
   */
  brokenReason: BrokenReason | null;
};

type BrokenReason =
  | 'NO_ASSISTANT_REPLIES'
  | 'EMPTY_TRANSCRIPT'
  | 'MALFORMED'
  | 'UNKNOWN';
```

## Field semantics

### `isBroken`

- Always present (never undefined).
- True iff the session matched at least one broken-detection criterion.
- Persisted in `sessions.is_broken` BOOLEAN column (existing).

### `brokenReason`

- Present in the wire format; may be `null`.
- When `isBroken=true`: SHOULD be a typed enum member; MAY be `null` for legacy rows.
- When `isBroken=false`: MUST be `null`.
- Persisted in `sessions.broken_reason` TEXT column (new this release).

## Frontend rendering rule (FR-012)

```ts
// In BrokenBadge.tsx or equivalent:
const tooltipKey = `brokenReason.${session.brokenReason ?? 'UNKNOWN'}`;
const tooltipText = t(tooltipKey);
```

This guarantees:
- A session with `brokenReason: 'NO_ASSISTANT_REPLIES'` renders the "no assistant replies" tooltip.
- A session with `brokenReason: 'EMPTY_TRANSCRIPT'` renders the "empty transcript" tooltip.
- A session with `brokenReason: null` (legacy) renders the `UNKNOWN` fallback tooltip ("This session was flagged as not reviewable.").
- A new criterion added later (after adding its enum member + i18n key) is rendered automatically.

## Validation rules (FR ↔ data)

- **FR-009**: When `isBroken=true`, the row's `broken_reason` SHOULD be set to one of the enum members (or `'UNKNOWN'`).
- **FR-010**: All Session DTO responses MUST include both `isBroken` and `brokenReason` fields explicitly. They are not optional in the wire format (even if the value is `null`).
- **FR-011**: Each detection criterion writes the matching reason. Verified by unit tests on the broken-detection service.
- **FR-012**: Frontend tooltip copy is i18n-driven. No hardcoded strings.

## Backwards compatibility

- Existing frontend consumers that don't read `brokenReason` continue to work; they may show the old hardcoded tooltip until updated.
- Existing backend consumers that don't write `broken_reason` write NULL; legacy rows fall back to UNKNOWN at render time.
- TypeScript type changes:
  - `chat-backend/src/types/review.ts`: add `BrokenReason` union and `brokenReason` field to `SessionDTO`.
  - If the type is shared via `@mentalhelpglobal/chat-types` package: bump version, publish, and update consumers' `package.json`. Per the design doc, this lives in chat-backend's local types and is re-exported through `chat-types` per the existing pattern — confirm during implementation.

## Test contract

| Test | Verifies |
|------|----------|
| Unit (`tests/unit/services/broken-detection.test.ts`, "writes correct reason") | Each criterion writes its matching reason value |
| Unit (`tests/unit/services/broken-detection.test.ts`, "does not overwrite reason") | Idempotent re-detection on the same session does not flap reasons |
| Component (`workbench-frontend/src/__tests__/BrokenBadge.test.tsx`) | Each enum value + null produces the correct rendered tooltip text per locale |
| Component test fallback case | `brokenReason: null` renders the `UNKNOWN` tooltip (not a literal i18n key, not "no assistant replies") |
