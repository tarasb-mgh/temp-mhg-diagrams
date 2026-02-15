# Phase 0 Research: Split Chat and Workbench Frontend + Backend

## Decision 1: Backend split model

**Decision**: Use independently deployable backend services for chat and
workbench to allow independent scaling and operational isolation.

**Rationale**:
- Directly satisfies clarification requirement for independent scaling.
- Reduces noisy-neighbor risk during workload spikes in one surface.
- Supports clear ownership, rollout, and rollback boundaries.

**Alternatives considered**:
- Single shared backend with route segregation only (rejected: weaker scaling isolation).
- Fully separate product stacks including auth duplication (rejected: unnecessary scope and risk).

## Decision 2: Domain topology by environment

**Decision**: Preserve existing chat domains and introduce dedicated workbench
frontend/API domains:
- Production: `workbench.mentalhelp.chat`, `api.workbench.mentalhelp.chat`
- Development: same naming pattern for workbench FE/API hosts.

**Rationale**:
- Provides explicit boundary between surfaces and APIs.
- Simplifies route intent and smoke validation.
- Aligns with prior domain-driven operational patterns.

**Alternatives considered**:
- Path-based split on shared host only (rejected: weaker boundary clarity and CORS risk).

## Decision 3: Access and contract isolation

**Decision**: Enforce authorization and payload contract boundaries at each
backend service surface so workbench-only capabilities are never available via
chat API paths.

**Rationale**:
- Implements FR-012/FR-013 directly.
- Prevents cross-surface leakage and privilege confusion.

**Alternatives considered**:
- Frontend-only segregation with shared broad API (rejected: policy bypass risk).

## Decision 4: Transition continuity strategy

**Decision**: Keep deterministic legacy route mapping and recovery paths while
moving users toward canonical split domains/routes.

**Rationale**:
- Preserves user continuity during migration.
- Reduces support friction from old bookmarks.

**Alternatives considered**:
- Hard cutover with no compatibility mapping (rejected: high disruption risk).

## Decision 5: Verification evidence model

**Decision**: Require release evidence for:
1) frontend split routing and deep links,  
2) backend boundary behavior and role enforcement,  
3) prod/dev domain correctness and CORS/API smoke,  
4) responsive/PWA continuity.

**Rationale**:
- Satisfies constitution Principles III, VIII, and IX.
- Ensures domain and service split correctness is observable before release.

**Alternatives considered**:
- Manual smoke checks without artifacted evidence (rejected: weak auditability).
