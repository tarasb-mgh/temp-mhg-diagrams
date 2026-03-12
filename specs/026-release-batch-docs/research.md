# Research: Release Batch — v2026.03.11

**Feature**: 026-release-batch-docs
**Phase**: 0 — Technical Decisions (Retrospective)
**Date**: 2026-03-11

---

## 1. Session Persistence Strategy

**Decision**: Use `localStorage` with key `mhg_chat_session_id` to persist the active
session ID across page reloads for authenticated users.

**Rationale**:
- `localStorage` survives page reload and browser restart (unlike `sessionStorage`)
- Scoped to origin — no cross-domain leakage
- Simple synchronous API with no additional dependencies
- Cleared deterministically on: explicit session end, user logout, user-identity switch

**Alternatives considered**:
- `sessionStorage` — rejected: does not survive tab close/reload
- Cookie — rejected: adds complexity for expiry management and CSRF surface
- Server-side session registry + polling — rejected: unnecessary network overhead

**Security considerations**:
- Auth subscriber in Zustand store clears the key on user-identity change to prevent
  cross-user session exposure (addressed after code review in PR #101)
- Guest users are explicitly excluded from resume to avoid ownership ambiguity

---

## 2. Offline / Network Error Detection

**Decision**: Detect network errors by catching `TypeError` and checking if the message
contains `fetch`, `network`, or `Failed` (case-insensitive match).

**Rationale**:
- The Fetch API throws `TypeError: Failed to fetch` on network failure across all
  major browsers — there is no standardized `NetworkError` subclass
- This heuristic correctly distinguishes network unreachability from HTTP errors
  (4xx/5xx), which arrive as resolved responses with non-OK status

**Alternatives considered**:
- `navigator.onLine` — rejected: can report `true` even on captive portal / limited
  connectivity; used only for initial state, not per-request detection
- Checking `error.name === 'TypeError'` alone — rejected: TypeErrors can have
  non-network causes; message content narrows the match

---

## 3. Retry Loop Re-entrancy

**Decision**: Guard `retryPendingMessages()` with a module-level `retryPendingLock`
boolean set to `true` at entry and cleared in a `finally` block.

**Rationale**:
- The `online` event can fire multiple times in rapid succession on reconnect
- Without a guard, multiple concurrent retry loops would each dequeue and re-send
  the same pending messages, causing duplicate sends
- Module-level (not store-level) placement means the guard persists across
  React re-renders and store resets

**Alternatives considered**:
- Zustand state flag — rejected: state updates are async and the check-then-set
  window creates a race condition
- Debouncing the `online` handler — rejected: masks the root issue and adds delay

---

## 4. RAG Data Visibility Gating

**Decision**: Gate RAG call detail display on the `testerTagAssigned` field of
`AuthenticatedUser`, evaluated server-side at message generation time and included
in the message API response payload (not persisted to the database).

**Rationale**:
- Tester status must be verified server-side to prevent client-side bypass
- Not persisting RAG data keeps the database schema clean and avoids storing
  potentially large retrieval payloads for all messages
- Including it in the API response (ephemeral) is sufficient for the tester
  use case — testers are online and can see the data in real time

**Alternatives considered**:
- Persisting RAG data for all messages — rejected: storage cost, schema complexity,
  and privacy implications of storing AI model internals
- Client-side gating only — rejected: trivially bypassable

---

## 5. Survey Gate Architecture

**Decision**: Use a server-side `GET /api/chat/gate-check` endpoint as the authoritative
gate, backed by a `survey_responses` table that records completion per user per survey
instance. The chat frontend calls this endpoint on session start to determine whether
to show the survey or proceed to chat.

**Rationale**:
- Gate must be server-enforced to be tamper-proof
- Separating gate-check from session creation keeps the session API clean
- Recording completion in the database ensures persistence across devices and sessions

**Alternatives considered**:
- localStorage completion flag — rejected: trivially bypassable, not cross-device
- Embedding gate logic in session creation — rejected: mixes concerns; session
  creation should not be blocked on survey state

---

## 6. Survey Instructions Storage Location

**Decision**: Move `instructions` from `survey_instances` to `survey_schemas`.

**Rationale**:
- Instructions describe the question structure and wording — they are properties
  of the schema template, not of any particular deployment instance
- This enables instructions to be authored once in the schema editor and inherited
  by all instances, rather than requiring per-instance editing
- The workbench schema editor is the natural home for this field

**Migration**: A database migration added the `instructions` column to `survey_schemas`
and backfilled from the most recent instance for existing schemas where applicable.
