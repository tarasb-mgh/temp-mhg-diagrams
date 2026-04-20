# Data Model: Reviewer Review Queue

**Feature**: `058-reviewer-review-queue`
**Date**: 2026-04-16
**Phase**: Phase 1 — Design & Contracts

This document describes the entities, fields, relationships, validation rules, and lifecycle / state transitions for the Reviewer Review Queue feature. Source of truth is `spec.md` Key Entities + Functional Requirements; types live in `chat-types`, persisted by `chat-backend`.

## Conventions

- All entity names use PascalCase; field names use camelCase in TypeScript types and snake_case in the database (Knex migration layer translates).
- Timestamps are ISO-8601 strings (`YYYY-MM-DDTHH:mm:ss.sssZ`) on the wire, `timestamptz` in Postgres.
- All IDs are UUID v4 unless noted otherwise.
- All "anonymised" Reviewer-facing IDs are short collision-resistant tokens derived deterministically from the underlying UUID via a server-side anonymisation function (decision deferred — see research.md).

---

## 1. Reviewer (existing — read-only consumer)

Existing `users` table; this feature does not create or migrate it. Relevant fields:

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `email` | string | Unique. |
| `role` | enum | One of `Reviewer`, `Researcher`, `Supervisor`, `Expert`, `Administrator`, `Master`. `Reviewer` and `Researcher` are equivalent for 058. |
| `displayName` | string | Optional. |
| `localePreference` | enum | One of supported locale codes (`uk`/`ru`/`en`...). FR-002a. |
| `is_active` | bool | EC-09. |

Relationships: many-to-many with Space via `space_memberships` (existing).

---

## 2. Space (existing — read-only consumer)

Existing `spaces` and `space_memberships` tables. Relevant fields:

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `name` | string | Display label in dropdown. |
| `slug` | string | Unique. |

`space_memberships`:

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `space_id` | UUID FK | → `spaces.id` |
| `user_id` | UUID FK | → `users.id` |
| `joined_at` | timestamp | |
| `removed_at` | timestamp nullable | EC-09a soft-removal |

Used by 058 only via existing read APIs. Membership CRUD is out of scope.

---

## 3. ChatSession

| Field | Type | Required | Notes / Validation |
|---|---|---|---|
| `id` | UUID | yes | PK; anonymised on the wire as short token. |
| `spaceId` | UUID | yes | FK → `spaces.id`; routes the session to the Space queue (FR-010, FR-010b). |
| `userId` | UUID | yes | FK → `users.id` of chat user; anonymised on the wire (PII). |
| `language` | enum | yes | One of supported locale codes; matches the chat conversation language (FR-021a, FR-024c). |
| `riskLevel` | enum | yes | `none` / `low` / `medium` / `high`. |
| `messageCount` | int | yes | Computed on save. |
| `startedAt` | timestamp | yes | |
| `endedAt` | timestamp | yes | Triggers routing to Review Queue (FR-010b). |
| `requiredReviewerCount` | int | yes | Snapshot from Review Settings AT QUERY TIME (Decision 11); stored as a virtual / computed column for paging convenience. |
| `completedReviewerCount` | int | yes | Aggregate over `Review.state = COMPLETED` for this session. |
| `status` | enum | yes | Lifecycle (see below). |

State machine:

```
PENDING ──(requirements met)──► READY_FOR_SUPERVISION ──(supervised)──► CLOSED
   │                                       ▲
   └───(soft RFC return ── REPEAT)─────────┘
```

For 058 the Reviewer only sees PENDING and the rows in the Reviewer's `Completed` tab (which are PENDING from the Reviewer's POV but already have a Review by this Reviewer, plus READY_FOR_SUPERVISION rows that this Reviewer is excluded from rating again).

Indexes: `(space_id, status)`, `(space_id, language)`, `(ended_at desc)`, `(status, completed_reviewer_count)` for the EC-17 / EC-18 recompute query.

---

## 4. Message

Existing message table; relevant fields:

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `sessionId` | UUID FK | |
| `role` | enum | `user` / `assistant` |
| `content` | text | Server-side PII detector replaces with `[REDACTED:type]` BEFORE shipping to Reviewer (FR-047c). |
| `createdAt` | timestamp | |

The PII detector is a middleware over the read endpoint, NOT a stored mutation. The original `content` is preserved at rest; only the wire payload is masked when the consumer is a Reviewer.

---

## 5. Rating

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | yes | |
| `reviewId` | UUID FK | yes | → `Review.id` |
| `messageId` | UUID FK | yes | → `Message.id` (assistant message only). |
| `score` | int | yes | 1..10. |
| `criterionId` | enum nullable | conditional | One of 8 hard-coded IDs: `relevance`, `empathy`, `psychological_safety`, `ethical_integrity`, `clarity_tone`, `request_match`, `autonomy`, `artificiality` (FR-014). |
| `criterionComment` | text nullable | conditional | Required when `criterionId IS NOT NULL` AND `score >= 8`; required when `score < 8`. |
| `validatedAnswer` | text nullable | conditional | Required when `score < 8`. |
| `versionStatus` | enum | yes | `canonical` (default) / `superseded` (FR-040, FR-041). |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

Validation (server-enforced + mirrored client-side gating):

- `score < 8` → `criterionId`, `criterionComment`, `validatedAnswer` MUST be non-null and non-empty.
- `score >= 8 AND criterionId IS NOT NULL` → `criterionComment` MUST be non-null and non-empty.
- `score >= 8 AND criterionId IS NULL` → `criterionComment`, `validatedAnswer` MAY be null.

Indexes: `(reviewId)`, `(messageId, versionStatus)`.

---

## 6. ClinicalTagDef (existing, extended)

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | yes | |
| `name` | string | yes | Display label, i18n via `language_group`. |
| `description` | text nullable | no | Hover tooltip (FR-024d). |
| `language_group` | string[] | yes | Set of supported locale codes (FR-021a). Default `["uk"]` for migrated rows. |
| `expert_assignments` | UUID[] | yes | FK list → `users.id` of Experts; routing fan-out. |
| `deleted_at` | timestamp nullable | no | Soft-delete (FR-021b). |

---

## 7. ClinicalTagAttachment (new in 058)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tagDefId` | UUID FK | → `ClinicalTagDef.id` |
| `messageId` | UUID FK | → `Message.id` |
| `reviewId` | UUID FK | → `Review.id` (private to that Reviewer per FR-023). |
| `createdAt` | timestamp | |

Indexes: `(reviewId)`, `(messageId, reviewId)` unique pair to prevent duplicate same-tag-on-same-message-by-same-reviewer attachments where redundant.

---

## 8. ReviewTagDef (existing, extended)

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | yes | |
| `name` | string | yes | |
| `description` | text nullable | no | (FR-024d) |
| `language_group` | string[] | yes | (FR-024c) |
| `deleted_at` | timestamp nullable | no | (FR-021b) |

No `expert_assignments` (FR-024e).

---

## 9. ReviewTagAttachment (new in 058)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `tagDefId` | UUID FK | → `ReviewTagDef.id` |
| `sessionId` | UUID FK | → `ChatSession.id` (session-level, not message-level — FR-024a). |
| `attachedByUserId` | UUID FK | → `users.id`. (Visible across Reviewers in the Space — FR-024f.) |
| `createdAt` | timestamp | |

Indexes: `(sessionId)`, unique `(sessionId, tagDefId)` to prevent duplicates.

---

## 10. MessageTagComment

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `messageId` | UUID FK | |
| `reviewerId` | UUID FK | (per the (message, Reviewer) pair scope per FR-022). |
| `body` | text | NOT NULL, NOT EMPTY when at least one ClinicalTagAttachment with `(messageId, reviewId of reviewer)` exists. |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

Unique key: `(messageId, reviewerId)`.

---

## 11. RedFlag

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `messageId` | UUID FK | (FR-025) |
| `reviewerId` | UUID FK | author |
| `description` | text | NOT NULL, NOT EMPTY (FR-026) |
| `state` | enum | `draft` / `submitted` (drives FR-028 email trigger) |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |
| `submittedAt` | timestamp nullable | set when the parent Review submits |

---

## 12. Review

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `sessionId` | UUID FK | |
| `reviewerId` | UUID FK | |
| `state` | enum | `DRAFT` (UNFINISHED), `COMPLETED`, `AWAITING_CHANGE_DECISION`, `REPEAT_DRAFT`, `REPEAT_COMPLETED` |
| `versionStatus` | enum | `canonical` / `superseded` (mirrors Rating) |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |
| `submittedAt` | timestamp nullable | |

Lifecycle (FR-035, FR-036, FR-038, FR-039, FR-040, EC-08):

```
DRAFT (UNFINISHED) ──submit──► COMPLETED ──RFC sent──► AWAITING_CHANGE_DECISION
                                                                │
                                                       (Supervisor approves)
                                                                │
                                            ┌───────────────────┘
                                            ▼
                                    REPEAT_DRAFT ──submit──► REPEAT_COMPLETED
                                            ▲
                                       (becomes canonical;
                                        prior COMPLETED moves to
                                        versionStatus=superseded)
```

Per-Reviewer uniqueness on `(sessionId, reviewerId, versionStatus = canonical)`.

---

## 13. ChangeRequest

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `reviewId` | UUID FK | |
| `requesterId` | UUID FK | Reviewer |
| `reason` | text | NOT NULL, NOT EMPTY (FR-036) |
| `decision` | enum nullable | `approved` / `rejected` |
| `decisionReason` | text nullable | required when `decision = rejected` |
| `decidedByUserId` | UUID FK nullable | Supervisor |
| `decidedAt` | timestamp nullable | |
| `createdAt` | timestamp | |

State machine:

```
PENDING ──approve──► APPROVED  (forks REPEAT_DRAFT on parent Review)
   │
   └──reject────► REJECTED
```

EC-08: APPROVE on a session whose parent Review is no longer eligible (parent supervised) → server returns 409 with code `SESSION_NOT_EDITABLE_AFTER_SUPERVISION` (per FR-042).

---

## 14. Notification

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `userId` | UUID FK | recipient |
| `category` | enum | `change_request.decision` / `red_flag.supervisor_followup` / `space.membership_change` (FR-039b) |
| `payload` | jsonb | category-specific |
| `createdAt` | timestamp | |
| `readAt` | timestamp nullable | dismiss → `notification.read` audit (FR-039a) |

Indexes: `(userId, readAt)`, `(userId, category, createdAt desc)`.

---

## 15. AuditLogEntry (existing, extended)

| Field | Type | Notes |
|---|---|---|
| `id` | bigserial | PK; monotonically increasing |
| `eventType` | string | dotted, e.g. `rating.created`, `notification.read`, `review_settings.required_count_changed`, `tag.soft_deleted`, `session.recomputed_completion`, `purge.run`, `login.failed` |
| `actorUserId` | UUID nullable | |
| `actorRole` | string nullable | |
| `ip` | inet nullable | |
| `target` | jsonb | category-specific entity reference |
| `payload` | jsonb | event-specific payload (NEVER contains unmasked PII) |
| `legalHold` | bool | default false; pass-through (FR-050b) |
| `createdAt` | timestamp | |
| `tier` | enum | `hot` / `warm` / `cold` (computed by retention job) |

Append-only — no UPDATE / DELETE triggers, role grants exclude UPDATE/DELETE.

Partitioning: monthly partition on `createdAt`. Retention job (Cloud Run cron) migrates the warm partition to GCS Parquet at month 36 boundary, restores on demand for 24h.

---

## 16. AdminSetting (extended — new key)

Existing settings table or a new key in the existing one:

| Key | Type | Default | Notes |
|---|---|---|---|
| `verbose_autosave_failures` | bool | `false` | FR-031c, FR-031d. Surfaced in admin UI as the canonical Toggle. |
| `required_reviewer_count` | int | `2` | Already exists per dev audit (Review Settings page). FR-008b governs propagation. |

---

## 17. OfflineQueueEntry (client-only, no backend table)

Stored in browser IndexedDB:

| Field | Type | Notes |
|---|---|---|
| `id` | string | client-generated UUID |
| `sessionId` | UUID | parent session reference |
| `payload` | object | Full PUT/POST body queued for replay |
| `attempts` | int | retry counter |
| `enqueuedAt` | number | epoch ms |

Replayed in insertion order on `ping` recovery (FR-031b). Cleared on successful sync; per-Reviewer namespace to avoid leak across sequential sign-ins on the same device (Privacy CHK017).

---

## Cross-Entity Invariants

1. **Per-Reviewer canonical uniqueness**: `(sessionId, reviewerId, Review.versionStatus = 'canonical')` MUST be unique. Repeat submit moves the previous canonical to `superseded`.
2. **Submit gating** (mirrors FR-018): backend rejects `POST /api/reviews/:id/submit` unless every assistant message has a Rating, every Rating with `score < 8` has `criterionId / criterionComment / validatedAnswer`, every (message, reviewerId) pair with at least one ClinicalTagAttachment has a non-empty MessageTagComment, and every RedFlag has a non-empty description.
3. **Soft-delete tag visibility**: Reviewer-facing tag list endpoint filters `WHERE deleted_at IS NULL`; tag attachments fetched as part of session detail include the soft-deleted tag's name + `deleted_at` timestamp + chip "(deleted)" prefix flag.
4. **Space scope**: every Reviewer-side query carries `WHERE chatSession.space_id IN (Reviewer's active Space membership ids)`. The Space dropdown selection narrows to a single space; "All Spaces" lifts the narrowing but never escapes the membership set.
5. **Notification ownership**: every Notification belongs to exactly one User; cross-user fetch is forbidden by RBAC at the route level.
6. **PII masking layer**: every `Message.content` field shipped through the Reviewer route is processed by the PII detector middleware (Decision 6); the unmasked value is never logged, traced, or echoed in audit log target/payload fields.

---

## Summary

- **17 entities** (some existing read-only, some extended with new attributes, some new).
- **Major new entities introduced by 058**: `MessageTagComment`, `ClinicalTagAttachment`, `ReviewTagAttachment`, `RedFlag`, `Review`, `Rating`, `ChangeRequest`, `Notification`, plus IndexedDB-only `OfflineQueueEntry`.
- **Major extensions to existing entities**: `ClinicalTagDef.language_group + description + deleted_at`, `ReviewTagDef` likewise, `AuditLogEntry.legalHold + tier`, `AdminSetting.verbose_autosave_failures`.
- All shapes are mirrored 1:1 in `chat-types`.
