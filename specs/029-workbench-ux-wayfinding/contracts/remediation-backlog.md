# Contract: UX Remediation Backlog Item Schema

## Purpose

Provide a normalized, implementation-ready format for converting P1/P2 findings into deliverable tasks routed to target repositories.

## Required Item Fields

Each remediation item must include:

- `id`: stable identifier
- `severity`: `P1` | `P2` | `P3`
- `source_finding_id`: reference to `UXFinding.id`
- `owner_repo`: `workbench-frontend` | `chat-frontend-common` | `chat-backend`
- `target_path`: repository-relative path
- `problem`: concise issue statement
- `proposed_change`: concrete implementation intent
- `acceptance_check`: explicit validation step
- `dependencies`: list of prerequisite item IDs (or empty)

## Repository Routing Map

- `workbench-frontend`
  - Navigation taxonomy, menu labels, breadcrumbs, back-context, next-step prompts.
- `chat-frontend-common`
  - Shared UX primitives and reusable helper behaviors (if cross-app reuse is required).
- `chat-backend` (conditional)
  - API metadata or endpoint behavior needed to support wayfinding state/visibility.

## Example Item (Template)

```md
- id: RB-001
  severity: P1
  source_finding_id: F1
  owner_repo: workbench-frontend
  target_path: src/features/workbench/navigation/Sidebar.tsx
  problem: Users cannot distinguish primary vs secondary sections.
  proposed_change: Introduce grouped section headers and deterministic ordering.
  acceptance_check: 5-role rerun confirms section discovery in <=3 clicks.
  dependencies: []
```

## Validation Rules

1. Every P1/P2 finding must map to at least one remediation item.
2. Every remediation item must have exactly one `owner_repo`.
3. `acceptance_check` must be testable in baseline/rerun flow scripts.
4. Items without `target_path` are invalid.

## Remediation Item Table Scaffold

| id | severity | source_finding_id | owner_repo | target_path | problem | proposed_change | acceptance_check | dependencies |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RB-000 | P2 | F0 | workbench-frontend | TBD | TBD | TBD | TBD | [] |

## Implementation-Ready Remediation Items (From Baseline)

| id | severity | source_finding_id | owner_repo | target_path | problem | proposed_change | acceptance_check | dependencies |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RB-001 | P1 | F1 | workbench-frontend | `src/features/auth/LoginPage.tsx` | Primary sign-in flow blocks role-based UX baseline completion. | Add explicit OTP fallback entry path and helper copy for approved dev accounts. | Baseline rerun reaches authenticated sidebar for all required roles via OTP path. | [] |
| RB-002 | P1 | F1 | chat-backend | `src/routes/auth.ts` | Dev auth flow does not reliably return a valid app session in automated audits. | Ensure OTP-based dev auth route/session handoff is deterministic for approved role matrix. | `POST` auth sequence yields valid session for all required role accounts in rerun. | [RB-001] |
| RB-003 | P1 | F5 | workbench-frontend | `src/features/workbench/navigation/Sidebar.tsx` | Navigation hierarchy is not validated against discoverability and return-path outcomes. | Implement role-aware IA grouping with deterministic ordering and breadcrumb compatibility. | Critical destinations are discoverable in `<= 3` clicks for all required roles. | [RB-001, RB-002] |
| RB-004 | P2 | F2 | workbench-frontend | `src/features/auth/LoginMethods.tsx` | Sign-in method discoverability is ambiguous in dev. | Add method labels and short purpose text for Google vs OTP fallback choices. | Testers identify approved sign-in path without external documentation. | [RB-001] |
| RB-005 | P2 | F3 | chat-frontend-common | `src/i18n/auth-entry.json` | Auth entry surfaces show inconsistent localization across visible labels. | Normalize auth-entry localization resources and enforce one language per session context. | No mixed-language labels on auth entry during rerun capture. | [RB-004] |
| RB-006 | P2 | F4 | chat-backend | `src/middleware/authRefresh.ts` | Repeated unauthenticated 401 responses produce noisy logs and reduce QA signal quality. | Reduce repetitive refresh/logout error noise and return a single deterministic unauth state. | Unauth bootstrap produces one clear auth-state event without repeated 401 spam. | [] |
