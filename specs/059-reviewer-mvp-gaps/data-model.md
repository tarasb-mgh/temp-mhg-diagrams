# Data Model: Reviewer MVP Gap Closure

**Feature**: `059-reviewer-mvp-gaps`
**Date**: 2026-04-22
**Phase**: Phase 1 — Design & Contracts

This document describes only the entity extensions and new entities
introduced by 059. For the baseline entity definitions, see
`specs/058-reviewer-review-queue/data-model.md`.

## Conventions

Same as 058: PascalCase entities, camelCase TS fields, snake_case DB
columns, ISO-8601 timestamps, UUID v4 IDs.

---

## 1. AdminSetting (extended — two new keys)

058 already exposes `guestModeEnabled`, `approvalCooloffDays`,
`otpLoginDisabledWorkbench`, `dynamicPermissionsEnabled`. This feature
adds:

| Key | Type | Default | Bounded | Notes |
|-----|------|---------|---------|-------|
| `verbose_autosave_failures` | boolean | `false` | — | FR-018. When ON, every failed save attempt surfaces a toast. When OFF, only persistent failures (3rd consecutive) surface. |
| `inactivity_timeout_minutes` | integer | `30` | [5, 480] | FR-015. The backend `sessionTimeoutCheck` middleware reads this value at request time (falls back to `SESSION_TIMEOUT_MINUTES` env var). |

**Migration**: `ALTER TABLE admin_settings ADD COLUMN IF NOT EXISTS
verbose_autosave_failures BOOLEAN NOT NULL DEFAULT false;` and
`ALTER TABLE admin_settings ADD COLUMN IF NOT EXISTS
inactivity_timeout_minutes INTEGER NOT NULL DEFAULT 30;` (or equivalent
key-value insert if the table uses a KV schema).

**Audit**: Changes to either key emit an audit entry with `eventType =
'admin_settings.updated'`, carrying `{key, oldValue, newValue}` in the
payload (FR-016).

---

## 2. Notification (extended — new category)

The 058 `review_notifications` table already supports categories
`change_request.decision` and `red_flag.supervisor_followup`. This
feature adds:

| Category | Payload shape | Trigger |
|----------|---------------|---------|
| `space.membership_change` | `{spaceName: string, direction: "added" \| "removed", timestamp: ISO-8601}` | Master user adds/removes a Reviewer from a Space |

No schema migration required — the `category` column is a `text` (not
an enum) and `payload` is `jsonb`.

**Dismiss audit**: Every `Dismiss` on any notification (all three
categories) writes a `notification.read` audit entry with `{reviewerId,
timestamp, category, notificationId}` (FR-022).

---

## 3. AuditLogEntry (extended — logical tier model)

058 added `legal_hold` (boolean, default false) to the audit log table.
This feature adds:

| Concept | Implementation | Notes |
|---------|---------------|-------|
| **Storage tier** | Logical, computed from `created_at` via `CASE WHEN age < 12 months THEN 'hot' WHEN age < 36 months THEN 'warm' ELSE 'expired' END` | FR-026. No physical column — the tier is a query-time classification. Cold tier deferred to infra. |
| **Purge eligibility** | `created_at < NOW() - INTERVAL '60 months' AND legal_hold = false` | FR-027, FR-028. |
| **Purge batch row** | `eventType = 'audit.purge'`, payload `{runSequenceId, removedCount, windowStart, windowEnd}` | FR-027. Exactly one per purge run. |

**Purge job**: A daily scheduled task (`setInterval` at 24h in the
backend process, same pattern as `expireOldSessions`) that:
1. Deletes rows matching the eligibility filter.
2. Appends exactly one `audit.purge` row.
3. Logs the run count to Pino.

**Warm-tier query**: The existing audit log query endpoint adds a comment
header `X-Audit-Tier: warm` for rows older than 12 months. The frontend
may display an "older data — may load slowly" indicator.

---

## 4. OfflineQueueEntry (client-only — no schema change)

The existing IndexedDB `OfflineQueueEntry` from 058 gains no new columns.
The behavioral change is in the Submit button integration (FR-001..003):
the Submit label reads `pendingOfflineCount` from the existing store and
renders `⟳ Submit (N)` / `Submit` accordingly.

---

## 5. New shared UI components (no backend entity)

These are frontend-only components with no backend persistence:

| Component | Location | Purpose |
|-----------|----------|---------|
| `LoadingSkeleton` | `workbench-frontend/src/components/states/` | FR-007: skeleton placeholders within 200ms |
| `EmptyState` | `workbench-frontend/src/components/states/` | FR-008: illustration + headline + CTA |
| `ErrorState` | `workbench-frontend/src/components/states/` | FR-009: error code + description + Retry + support |
| `UnsavedChangesModal` | `workbench-frontend/src/components/` | FR-013: in-app navigation guard |
| `BrowserCapabilityGuard` | `workbench-frontend/src/components/` | FR-023: full-page unsupported browser notice |

---

## Cross-Entity Invariants (059-specific)

1. **Admin setting bounds**: `inactivity_timeout_minutes` MUST be
   clamped to [5, 480] at both the frontend input level and the backend
   PATCH handler. Values outside bounds return 400.
2. **Purge + legal_hold**: The purge job MUST never delete a row with
   `legal_hold = true`, regardless of age. The `legal_hold` column is
   pass-through (no UI in this feature).
3. **Notification category exhaustiveness**: The bell/banner renderer
   MUST handle all three categories; an unknown category string MUST
   render a generic "New notification" fallback, not crash.
4. **Toggle component parity**: Every toggle on the Admin and Reviewer
   Settings pages MUST use the canonical `Toggle` from
   `chat-frontend-common`. No custom slider buttons.
5. **Retired tag term**: The canonical prefix is `(retired)` (never
   `(deleted)` or `(archived)`) across chips, tooltips, locale keys,
   and E2E assertions.

---

## Summary

- **0 new backend tables** — all changes are column additions or new
  key-value entries in existing tables.
- **1 new notification category** (`space.membership_change`) using
  existing `review_notifications` table.
- **2 new admin setting keys** (`verbose_autosave_failures`,
  `inactivity_timeout_minutes`).
- **1 logical tier model** for audit log (no physical migration).
- **1 purge job** (scheduled task, not Cloud Run Job).
- **5 new shared frontend components** (states + modal + guard).
- **0 new backend endpoints** — all changes go through existing
  `GET/PATCH /api/admin/settings`, existing notification endpoints,
  existing audit log query endpoint.
