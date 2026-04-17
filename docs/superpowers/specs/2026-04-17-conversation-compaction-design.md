# Conversation Compaction Design

**Date**: 2026-04-17
**Status**: Design approved by owner; ready for `/speckit.specify`
**Author**: Taras Bobrovytskyi (with Claude)
**Target repos**: `chat-backend`, `workbench-frontend`, `client-spec` (specs only)

## 1. Incident Background

On 2026-04-16, production chat-backend emitted 48 × HTTP 500 responses on `POST https://api.mentalhelp.chat/api/chat/message`. Every single failure was the same root error surfaced by the Dialogflow CX client:

```
9 FAILED_PRECONDITION: com.google.apps.framework.request.FailedPreconditionException:
Token limit exceeded: got {N}, expected less than 8192
Code: FAILED_PRECONDITION
```

Distribution of `{N}`:

| `got` | Count |
|---|---|
| 8248 | 10 |
| 8252 | 2 |
| 8346 | 6 |
| 8353 | 2 |
| 8648 | 6 |
| 20678 | 2 |

The 8248–8648 cluster reflects conversations that grew gradually past the 8192-token input ceiling of the CX agent's underlying LLM. The 20678 outlier reflects a single turn whose combined input (playbook + CX-held history + data-store retrievals from the GCS knowledge base) was pushed over the limit by verbose `extractive_answers` hits.

End-user impact: the chat frontend displayed **"Невдома надіслати"** ("Failed to send") with a Retry button. Zero errors on 2026-04-15; the 48 errors were concentrated on 2026-04-16 across three bursts (07:40–07:43 UTC, 12:46 UTC, 18:57–20:03 UTC), suggesting a CX agent or playbook change deployed that day tipped typical sessions past the ceiling.

Relevant infrastructure:

- **Backend**: `chat-backend` Express service on Cloud Run (project `mental-help-global-25`).
- **CX agent**: `192578e5-f119-436e-9718-abb9d9d1c8b1` (global region).
- **Admin surface**: `workbench.mentalhelp.chat`.
- **End-user surface**: `mentalhelp.chat` (must remain visually unchanged).

## 2. Goal

Prevent token-limit overflow from ever reaching the end user, while preserving clinical continuity of the assistant's behavior across the overflow boundary, and giving admins a Workbench-level knob to tune the mechanism.

### 2.1 Ground rules (owner-specified, not up for debate)

- When active conversation context is about to overflow the LLM input budget, compact the **oldest 1/3** of the conversation into a persistent memory summary and remove those messages from what is sent to CX on subsequent turns.
- Memory must preserve tone, prior safety disclosures, stated user preferences — the clinical continuity that a human therapist would remember.
- Compaction must be **imperceptible to the end user**. No visible spinner, no perceptible latency added on the send path.
- The `1/3` ratio is a **default**, not a constant. Admins configure it in Workbench settings.

### 2.2 Non-goals (explicit)

- Upgrading the CX agent's underlying LLM model.
- Tuning data-store `max_extractive_answers` / `max_snippet_count`.
- Any visible change to the chat end-user UI.
- Per-user, per-space, or per-chatbot compaction tuning.
- Guaranteeing zero 5xx under all conditions — only zero 5xx **attributable to token-limit overflow on repeatable sessions**.

## 3. Key Architectural Constraint

Dialogflow CX owns conversation history **server-side, per CX session**. The backend's `detectIntent` call (`chat-backend/src/dialogflow.ts:193-223`) sends only the current turn's text plus session parameters — CX retrieves its own history internally, runs the playbook, retrieves data-store hits, and produces a reply. The 8192-token ceiling is CX's *combined* LLM input, which the backend cannot directly measure or trim.

**Consequence**: "compact the oldest 1/3" cannot be implemented as backend-side array slicing. It must be implemented as **CX session rotation** — the backend creates a new CX session, preloads a summary of the compacted messages via the existing `agentMemorySystemMessages` session-parameter channel (`dialogflow.ts:180-191`), and routes subsequent turns to the new session. The old CX session is abandoned; its history is no longer referenced.

## 4. Architecture

```
                        chat-backend (Cloud Run)
 +-----------------------------------------------------------------+
 |                                                                 |
 |  POST /api/chat/message                                         |
 |       |                                                         |
 |       v                                                         |
 |  +------------------+    +---------------------------------+    |
 |  | compaction gate  |--->| route to ACTIVE CX session      |------> Dialogflow CX
 |  +------------------+    | (may be pre-rotated)            |       (detectIntent)
 |       |                  +---------------------------------+    |
 |       | over soft budget?                                       |
 |       v                                                         |
 |  +------------------+                                           |
 |  | background       |  (setImmediate; Cloud Tasks for retry)    |
 |  | summarizer       |-----> Vertex AI Gemini                    |
 |  |  - oldest 1/3    |       (stateless summarization call)      |
 |  |  - writes:       |                                           |
 |  |   messages.      |                                           |
 |  |   compacted_at   |                                           |
 |  |   chat_sessions. |                                           |
 |  |   active_cx_sid  |                                           |
 |  |   chat_sessions. |                                           |
 |  |   compaction_    |                                           |
 |  |   summary        |                                           |
 |  +------------------+                                           |
 +-----------------------------------------------------------------+
                                 ^
                                 | GET/PATCH /api/admin/settings
                                 | (4 new global keys)
                                 |
                       workbench-frontend (Admin UI)
```

### 4.1 Reused infrastructure

- `agentMemorySystemMessages` CX session-parameter channel (`dialogflow.ts:180-191`), already capped at 12 slices.
- `services/agentMemory/agentMemory.service.ts` and `prompts.ts` — prompt scaffolding and cross-session USER MEMORY aggregation.
- `services/settings.service.ts` global singleton — add 4 columns.
- `routes/admin.settings.ts` PATCH endpoint — extend validator.
- Workbench admin settings UI pattern (existing).
- `services/cloud-tasks.service.ts` — available for durable background retry if `setImmediate` proves insufficient.

### 4.2 Net-new surface

- `services/compaction/compaction.service.ts` — orchestrator.
- `services/compaction/summarizer.client.ts` — Vertex AI Gemini wrapper.
- `services/compaction/prompts.ts` — summarization system prompt (UK/RU/EN).
- `services/compaction/tokenEstimator.ts` — character/3.5 heuristic.
- `services/compaction/circuitBreaker.ts` — in-memory, per-instance.
- `jobs/compaction.job.ts` — background worker entry point.
- DB migration: 3 column additions across 3 tables.
- Workbench admin UI: 4 form fields + circuit-breaker health badge.
- IAM: `roles/aiplatform.user` on chat-backend prod service account.

## 5. Data Model

```sql
-- 1. per-message compaction flag
ALTER TABLE messages
  ADD COLUMN compacted_at TIMESTAMPTZ NULL;
CREATE INDEX idx_messages_session_compacted ON messages(session_id, compacted_at);

-- 2. per-session compaction state
ALTER TABLE chat_sessions
  ADD COLUMN active_cx_session_id UUID NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN compaction_summary TEXT NULL,
  ADD COLUMN compaction_summary_updated_at TIMESTAMPTZ NULL,
  ADD COLUMN compactions_count INTEGER NOT NULL DEFAULT 0;
-- Migration backfill: for pre-existing rows, set active_cx_session_id = chat_sessions.id
-- so existing sessions continue routing to the same CX session they used before.

-- 3. global settings columns (singleton table)
ALTER TABLE settings
  ADD COLUMN compaction_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN compaction_ratio NUMERIC(3,2) NOT NULL DEFAULT 0.33,
  ADD COLUMN compaction_max_messages INTEGER NOT NULL DEFAULT 40,
  ADD COLUMN compaction_soft_token_budget INTEGER NOT NULL DEFAULT 5500;
```

Bounds enforced at the API validator layer, not the DB:

- `compaction_ratio ∈ (0, 0.5]`
- `compaction_max_messages ∈ [10, 200]`
- `compaction_soft_token_budget ∈ [2000, 7500]` (ceiling deliberately below 8192 to leave headroom for CX-side content we don't measure)

Feature ships with `compaction_enabled = false`; flip via Workbench settings PATCH after dev soak.

## 6. Behavior

### 6.1 Compaction trigger (hybrid)

On every inbound `POST /api/chat/message`, after the successful `detectIntent` reply, the gate evaluates:

```
shouldCompact(session) =
  compaction_enabled AND
  circuit_breaker_state != OPEN AND (
    count(messages where compacted_at IS NULL AND session_id = S) >= compaction_max_messages
    OR
    estimate_tokens(messages where compacted_at IS NULL AND session_id = S) >= compaction_soft_token_budget
  )
```

The trigger is evaluated **after the user has received their reply** for turn N. The compaction runs in the background. The rotation is applied to turn N+1.

### 6.2 Selection of the oldest 1/3

```
chunk_size = ceil(count_non_compacted * compaction_ratio)
oldest_chunk = non_compacted messages, ordered by created_at asc, limited to chunk_size
```

With 40 messages and ratio 0.33: 14 messages summarized per compaction.

### 6.3 Summarization (Vertex AI Gemini)

- Model: `gemini-2.0-flash` (default; env-var configurable).
- Input: system prompt (clinical preservation rules + output-language match) + `existing_summary` (if any) + `oldest_chunk` (formatted as a turn-by-turn transcript).
- Output: a single paragraph in the same language as the conversation, preserving tone, prior disclosures, safety flags, stated user preferences, therapist and medication references, emotional context.
- Output length target: 500–1500 characters.
- Safety: Vertex's default safety filters apply; a filter-block triggers the placeholder-summary fallback (§ 7.3).

### 6.4 DB mutation on successful compaction (single transaction)

```
BEGIN TX
  UPDATE messages SET compacted_at = now() WHERE id IN (oldest_chunk_ids)
  UPDATE chat_sessions SET
    active_cx_session_id = gen_random_uuid(),
    compaction_summary = new_summary,
    compaction_summary_updated_at = now(),
    compactions_count = compactions_count + 1
  WHERE id = sessionId
COMMIT
```

The advisory lock (`pg_advisory_xact_lock` keyed on `sessionId`) is held for the entire background flow (Vertex call + DB TX) to prevent double-compaction. Typical hold: 800–1500 ms.

### 6.5 Turn N+1 on the rotated session

The inbound request handler attempts `pg_try_advisory_lock_shared` with a 1000 ms wait budget before reading `active_cx_session_id`.

- **Lock acquired quickly** → compaction is either finished or wasn't in flight. Read `active_cx_session_id` (may be the new UUID).
- **Wait times out** → compaction still in flight. Proceed with the currently-stored `active_cx_session_id` (best effort). Worst case: this turn lands on the about-to-be-retired session and either succeeds (the chunk we're compacting still fits) or 500s with the original `FAILED_PRECONDITION`. The subsequent turn will route to the new session.

The 1000 ms wait budget is an env-var so ops can tune it.

### 6.6 CX session parameters on the rotated session

`agentMemorySystemMessages` is rebuilt per `detectIntent` call as:

```
[
  { role: 'system', content: chat_sessions.compaction_summary },
  ...existing USER MEMORY entries from agentMemory.service.ts
]
```

The compaction summary occupies priority slot 0. If the 12-slice cap trims anything, it trims lowest-priority USER MEMORY entries first.

### 6.7 Summary-of-summary (nth compaction in one session)

Every compaction receives the current `compaction_summary` as prior context. The new summary supersedes the old in the single-row source of truth (`chat_sessions.compaction_summary`). No accumulating array; no drift across generations.

## 7. Error Handling

### 7.1 Failure taxonomy

| # | Failure | Handler |
|---|---|---|
| F1 | Vertex call errors (5xx, timeout, network) | Retry once with 250 ms backoff; if still failing → F5 |
| F2 | Vertex returns empty or trivially short summary (< 50 chars) | Same as F1 |
| F3 | Vertex safety filter blocks (`finishReason === 'SAFETY'`) | No retry; → F5 |
| F4 | 1/3 chunk exceeds Vertex input budget | Pre-split chunk in halves, summarize each, then summarize-of-summaries; if still failing → F5. Rare with Gemini 2.0 Flash's 1M-token input. |
| F5 | **Terminal summarizer failure** | Degraded-continuity rotation (§ 7.3) |
| F6 | `detectIntent` on new CX session fails | Normal 500 to client; no automatic re-rotation |
| F7 | User turn N+1 arrives during in-flight compaction | Race guard (§ 6.5) |
| F8 | Two background compactions race on the same session | Second fails advisory lock acquisition and exits cleanly |
| F9 | DB TX commit fails after Vertex success | Log warn; discard summary; next trigger re-summarizes |
| F10 | `compaction_enabled` flipped false mid-session | Gate is per-request; in-flight jobs complete normally |

### 7.2 Circuit breaker

In-memory per Cloud Run instance, keyed globally (not per-session):

- **Closed** — compaction triggers run.
- **Open** — ≥ 5 terminal summarizer failures in a 5-minute rolling window. `shouldCompact` returns false while open.
- **Half-open** — after 60 s in open state, next attempt runs; success → close, failure → reopen for 60 s.

State transitions log at `WARNING` severity. Current state exposed at `GET /api/admin/settings/compaction/health`; Workbench admin UI renders a colored badge.

### 7.3 Degraded-continuity rotation (F5 handler)

When terminal summarizer failure is reached, the background job still performs the DB mutation with a **template placeholder** in place of the LLM-generated summary:

```
[summary unavailable: {N} earlier messages were trimmed at {ISO timestamp}
 to prevent context overflow]
```

The session continues with USER MEMORY intact. The assistant loses in-session context for the compacted chunk but can keep going. This is the design's explicit trade: one turn of amnesia over a user-visible 500.

### 7.4 Observability

Per compaction, structured INFO log line with fields:

```
sessionId, cx_old, cx_new,
chunk_messages, chunk_est_tokens,
summary_length_chars,
vertex_latency_ms, total_latency_ms,
outcome ∈ { success, placeholder_fallback, skipped_breaker_open },
compactions_count,
existing_summary_present (bool)
```

In-process counters: `compaction_attempts_total{outcome=...}`, flushed to Cloud Logging periodically.

**Alert**: `placeholder_fallback / success > 5%` over a 1-hour rolling window.

## 8. Testing

| Layer | Scope | Tools | Rough count |
|---|---|---|---|
| Unit | `shouldCompact` predicate, `tokenEstimator`, circuit-breaker state machine, chunk-selection math, prompt assembly | Vitest | ~25 |
| Integration | `compaction.service` with mocked Vertex + real Postgres; advisory lock, TX atomicity, concurrency | Vitest + testcontainers | ~12 |
| Contract | Settings PATCH validator, health endpoint | Supertest | ~5 |
| E2E (dev) | Seeded conversation crosses threshold; rotation invisible to UI | Playwright MCP vs `https://dev.mentalhelp.chat` | ~3 |
| Load / soak (dev) | 50 concurrent sessions through one compaction cycle each | k6 one-off | — |

### 8.1 Vertex mock

`summarizer.fake.ts` with `succeed()`, `failWith(code)`, `blockForSafety()`, `timeoutAfter(ms)`. Makes F1–F4 deterministically testable. One contract test hits real Vertex on `main` branch CI only.

### 8.2 Judge-LLM for clinical preservation

For the 2–3 highest-stakes scenarios (e.g., "summary preserves a self-harm disclosure from turn 3"), a separate Vertex call with a yes/no grading prompt. Not used for every content assertion.

### 8.3 Race-condition coverage

Explicit tests for:

1. Two simultaneous inbound turns on the same session during an in-flight compaction.
2. User sends turn N+1 ~300 ms after turn N triggers compaction.

### 8.4 Regression suite hook

Add one smoke test asserting: after compaction, the Workbench Review Queue shows the **full** verbatim transcript (including compacted messages), and reviewers can still flag and rate the session.

### 8.5 Out of scope for automation

- Cross-language summary quality (UK/RU/EN) — manual QA per locale pre-flip.
- Very-long-term drift (20+ compactions on one session) — manual soak.
- Vertex cost tracking — manual spot-check, documented in runbook.

## 9. Acceptance Criteria

### 9.1 Latency SLOs

| Metric | Target |
|---|---|
| p50 `/api/chat/message` latency delta vs. baseline (all turns) | ≤ 0 ms |
| p95 `/api/chat/message` latency delta (all turns) | ≤ +30 ms |
| p99 `/api/chat/message` latency delta on compaction-trigger turn N | ≤ +50 ms |
| p99 `/api/chat/message` latency on turn N+1 **when race guard fires** | ≤ +1000 ms (the wait budget) |
| Background compaction wall-clock (lock acquire → TX commit) | p50 ≤ 1500 ms, p95 ≤ 3000 ms |

### 9.2 UX invariants

| Invariant | Verification |
|---|---|
| Zero loading states on chat UI attributable to compaction | Playwright E2E + manual QA across UK/RU/EN |
| Zero visible placeholder text on chat UI | Schema check on response payload; `compaction_summary` never serialized to chat client |
| Full transcript remains visible in Workbench Review Queue | Regression-suite smoke test |
| Assistant continuity preserved across compaction boundary | Manual QA scenario: safety disclosure in turn 3 → compact at turn 20 → verify reference on turn 21+ |

### 9.3 Reliability SLOs

| Metric | Target |
|---|---|
| Compaction success rate | ≥ 99% rolling 7 days |
| `placeholder_fallback` rate | < 1% rolling 1 hour; alert threshold 5% |
| chat-backend 5xx attributable to `FAILED_PRECONDITION: Token limit exceeded`, on sessions that have reached the compaction threshold ≥ 1 time | 0 |
| Circuit breaker state transitions per 24 h in steady state | ≤ 1 |

### 9.4 Incident-closure exit criterion

Reproduce the 2026-04-16 token-overflow conditions in dev:

1. Seed a dev session with the message distribution that produced the 8648-token cluster (long history + knowledge-base-heavy turns).
2. **Without** compaction: confirm session 500s with `Token limit exceeded` — establishes regression baseline.
3. **With** compaction enabled: same seed + same scripted turns produces **zero 500s across 20 consecutive runs**.

Manual checklist item in the prod-rollout runbook.

### 9.5 Rollout gates

1. All automated tests pass on `develop`.
2. Dev reproduction test (§ 9.4) passes.
3. Workbench admin UI manually verified UK/RU/EN.
4. `roles/aiplatform.user` provisioned on prod SA; synthetic Vertex call verified.
5. Cloud Logging compaction dashboard live.
6. Ship with `compaction_enabled = false`; enable in prod after ≥ 24 h clean dev soak.

## 10. Risks (owned, not resolved in this design)

| # | Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|---|
| R1 | Gemini 2.0 Flash retired / repriced before ship | Low | Medium | Model name env-var; summarizer client thin; one-file swap |
| R2 | Summary quality materially worse in RU/UK vs EN | Medium | Medium | Per-locale manual QA + judge-LLM for top clinical scenarios |
| R3 | Safety flag preserved semantically but not in the phrasing CX expects → downstream routing misfires | Medium | High | Explicit preservation rules in summary prompt; manual QA scenario; owner sign-off required |
| R4 | Pathologically long single message blows budget on one turn | Low | Medium | Hybrid trigger (count OR tokens) catches this; worst-case "oldest 1/3" is a tiny prefix — not elegant, not broken |
| R5 | `active_cx_session_id` rotation leaks CX session objects in Google's side | Low | Low | CX sessions auto-expire at 30 min idle TTL; quotas are per-second, not long-lived-count |
| R6 | Compaction enabled prod-wide triggers a new unforeseen incident | Medium | High | Ship dark; dev soak; prod flip via Workbench flag (no redeploy); runbook "flip flag" rollback |
| R7 | Per-instance circuit breaker → inconsistent state across Cloud Run instances | Medium | Low | Acceptable for v1; Redis-shared breaker is follow-up |

## 11. Decisions Locked by This Design

| Decision | Value |
|---|---|
| Compaction mechanism | CX session rotation; summary via `agentMemorySystemMessages` |
| Trigger | Hybrid: message-count OR backend token estimate, first to fire |
| Summary generator | Vertex AI Gemini (default `gemini-2.0-flash`), called from chat-backend, proactive post-trigger-turn |
| Settings granularity | Global singleton (4 new columns on `settings`) |
| Fate of compacted raw messages | Retain in DB, flag with `compacted_at TIMESTAMPTZ` |
| Error-handling bundle | Placeholder-summary fallback + circuit breaker + idempotent rotation with 1000 ms wait |
| Default ratio | 0.33 |
| Default message threshold | 40 |
| Default soft token budget | 5500 |
| Ship posture | `compaction_enabled = false` default; manual flip after soak |

## 12. Decisions Deferred

### 12.1 To `/speckit.plan`

- Exact file split between `compaction.service.ts`, `compaction.job.ts`, `summarizer.client.ts`.
- `setImmediate` vs. Cloud Tasks for the initial background implementation.
- Workbench UI layout (section, collapsible, tabbed).
- Whether `compacted_at` index is partial.
- Test file organization.

### 12.2 To operations post-ship

- When to enable on dev (after automated + manual tests).
- When to enable on prod (owner + author decision after ≥ 24 h clean dev soak).
- Tuning `compaction_ratio` / `maxMessages` / `softTokenBudget` from observed traffic.
- Whether to invest in per-chatbot overrides (Option B from Q4) — only if a second chatbot with distinct overflow profile appears.

## 13. Next Steps

1. Commit this design doc to `client-spec` `main` branch.
2. Run `/speckit.specify` with the one-sentence goal + acceptance criteria from this doc as the feature description — generates `specs/NNN-conversation-compaction/spec.md`.
3. Spec-document-reviewer subagent loop per `/mhg.specify` workflow.
4. `/speckit.clarify` loop to zero out remaining markers.
5. Create Jira Epic in MTB project.
6. `/mhg.plan`.
