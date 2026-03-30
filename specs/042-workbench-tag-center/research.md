# Phase 0 Research: Unified Workbench Tag Center

## Decision 1: Single Entry Point with Domain Modes

**Decision**: Implement one Tag Center entry point with two explicit modes: `User Tags` and `Review Tags`.

**Rationale**: This keeps discoverability high (one place for tag operations) while preserving domain clarity and preventing mixed-control overload.

**Alternatives considered**:
- Keep two separate pages and add cross-links: rejected because it preserves navigation fragmentation.
- Merge everything into one undifferentiated table: rejected because it increases operator error risk.

## Decision 2: Unified Backend API Surface

**Decision**: Use one unified tag-center backend contract for definition lifecycle, assignment, and profile-facing tag reads.

**Rationale**: A shared contract reduces duplication, aligns validation/error semantics, and simplifies long-term maintenance.

**Alternatives considered**:
- Keep dedicated `tester-tags` endpoints plus generic endpoints: rejected because it keeps dual behavior and migration overhead.
- Keep fully separate user/review APIs forever: rejected because it complicates governance and cross-domain consistency.

## Decision 3: Tester Tag Is a Standard User Tag

**Decision**: `tester` remains in the same user-tag model as other user tags, with no dedicated special-case workflow.

**Rationale**: This aligns with clarified scope and removes one-off behavior from both UI and backend.

**Alternatives considered**:
- Maintain a dedicated tester-only management module: rejected as unnecessary specialization.
- Convert tester state into a separate boolean field: rejected because it diverges from tag-based governance.

## Decision 4: Review-Tag Delete Guardrail

**Decision**: Block deletion of review tags if they are referenced by any review record (active or historical); allow archive/unarchive lifecycle instead.

**Rationale**: Prevents loss of historical traceability and avoids orphaned relationships.

**Alternatives considered**:
- Allow delete for historical references: rejected due to audit/data consistency risk.
- Always allow delete with cascading cleanup: rejected due to high integrity risk.

## Decision 5: Authorization Split

**Decision**:
- Rights-management and tag-definition lifecycle actions are gated.
- User-tag assignment/unassignment is not capability-gated and can target all users.

**Rationale**: This follows explicit business clarification while still protecting sensitive control surfaces.

**Alternatives considered**:
- Capability-gate every action: rejected based on clarified assignment policy.
- Remove gating from all actions: rejected due to security/operational risk.

## Decision 6: Search and Filtering Semantics

**Decision**: Use case-insensitive partial-text search over user name, user email, and tag name, with combined filters using AND logic.

**Rationale**: Deterministic semantics reduce ambiguity in implementation and E2E assertions.

**Alternatives considered**:
- Full-text/contains-any behavior: rejected because it weakens test determinism.
- Exact-match only: rejected because it is less operator-friendly.

## Decision 7: Reliability Measurement Protocol (SC-003)

**Decision**: Measure reliability with automated dev E2E runs: each happy flow executes in 10 consecutive runs; each run is counted independently.

**Rationale**: This makes the acceptance gate repeatable and objective.

**Alternatives considered**:
- Manual reliability counting: rejected due to low repeatability.
- Mixed manual+automated counting: rejected due to inconsistent evidence quality.

## Decision 8: Terminology Standardization

**Decision**: Standardize lifecycle language to `archive/unarchive` and avoid `restore`.

**Rationale**: A single canonical term set reduces ambiguity in requirements, tests, and UI copy.

**Alternatives considered**:
- Keep both `restore` and `unarchive`: rejected due to inconsistent semantics.
