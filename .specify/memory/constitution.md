<!--
  Sync Impact Report
  ==================
  Version change: (new) → 1.0.0

  Modified principles: N/A (initial version)

  Added sections:
  - Core Principles (6 principles)
  - Multi-Repository Orchestration
  - Development Workflow
  - Governance

  Removed sections: N/A (initial version)

  Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section exists)
  - .specify/templates/spec-template.md: ✅ Compatible (priority-based user stories supported)
  - .specify/templates/tasks-template.md: ✅ Compatible (test-first optional, user story organization)

  Follow-up TODOs: None
-->

# Mental Health Global Client-Spec Constitution

## Core Principles

### I. Spec-First Development

All features MUST begin with a specification before any implementation work.

- Feature work starts with `/speckit.specify` to capture WHAT and WHY
- Technical planning (`/speckit.plan`) follows specification approval
- Implementation (`/speckit.implement`) only proceeds after task breakdown
- No code changes without a corresponding spec in `specs/###-feature-name/`

**Rationale**: Specifications create shared understanding, reduce rework, and provide traceable requirements for features spanning multiple repositories.

### II. Multi-Repository Orchestration

This repository (`client-spec`) serves as the central orchestration point for feature development across multiple codebases.

- Specifications and plans live here; implementation happens in source repositories
- Primary source repository: `D:\src\MHG\chat-client` (React/TypeScript + Express backend)
- Each spec references target repository paths explicitly
- Cross-repository dependencies MUST be documented in plan.md

**Rationale**: Centralizing specifications enables coordinated feature development across frontend, backend, and any future repositories while maintaining a single source of truth for requirements.

### III. Test-Aligned Development

Tests MUST align with the source repository's established testing culture.

- **Unit tests**: Vitest + React Testing Library (frontend), Vitest (backend)
- **E2E tests**: Playwright for user-visible flows
- **Coverage thresholds**: Respect existing minimums (25% statements, 15% branches)
- **Test evidence**: Before/after screenshots stored in `evidence/<task-id>/`
- Tests are OPTIONAL in task generation unless explicitly requested

**Rationale**: The chat-client has a mature testing infrastructure. New features MUST integrate with existing patterns rather than introduce competing approaches.

### IV. Branch and Integration Discipline

Feature work MUST follow established branch policies.

- Feature branches: `###-feature-name` pattern (auto-numbered)
- Target integration branch: `develop` (not `main`)
- `main` is promotion-only; never commit directly
- All tests MUST pass before merge
- Squash merge for clean history

**Rationale**: The chat-client enforces strict branch protection. Specifications must align with this workflow to enable smooth handoff from planning to implementation.

### V. Privacy and Security First

Features touching user data MUST address privacy and security requirements upfront.

- GDPR compliance requirements documented in spec.md
- PII handling explicitly specified (masking, retention, deletion)
- Authentication/authorization changes require security review section
- Audit logging requirements for admin operations

**Rationale**: The chat-client handles sensitive mental health data. Privacy and security are non-negotiable and must be addressed at specification time, not retrofitted.

### VI. Accessibility and Internationalization

User-facing features MUST maintain WCAG AA compliance and i18n support.

- Accessibility requirements included in acceptance criteria
- All user-visible text MUST support translation (uk, en, ru)
- Keyboard navigation and screen reader compatibility required
- Contrast ratios and focus indicators specified where relevant

**Rationale**: The chat-client serves Ukrainian users seeking mental health support. Accessibility and language support are core product requirements, not optional enhancements.

## Multi-Repository Orchestration

### Repository Roles

| Repository | Role | Path |
|------------|------|------|
| `client-spec` | Specifications, plans, task orchestration | `D:\src\MHG\client-spec` |
| `chat-types` | Shared TypeScript types (`@mentalhelpglobal/chat-types`) | `D:\src\MHG\chat-types` |
| `chat-backend` | Express.js backend API | `D:\src\MHG\chat-backend` |
| `chat-frontend` | React frontend application | `D:\src\MHG\chat-frontend` |
| `chat-ui` | Playwright E2E tests | `D:\src\MHG\chat-ui` |
| `chat-ci` | Reusable GitHub Actions workflows | `D:\src\MHG\chat-ci` |
| `chat-infra` | GCP infrastructure scripts + Terraform | `D:\src\MHG\chat-infra` |
| `chat-client` | **Archived** monorepo (read-only after cutover) | `D:\src\MHG\chat-client` |

### Artifact Flow

1. **Specification** (`client-spec`): `/speckit.specify` creates `specs/###-feature/spec.md`
2. **Planning** (`client-spec`): `/speckit.plan` generates technical design artifacts
3. **Task Breakdown** (`client-spec`): `/speckit.tasks` creates actionable task list
4. **Implementation** (target repos): Execute tasks against `chat-backend`, `chat-frontend`, etc.
5. **Verification** (`client-spec`): Update task status, capture evidence

### Cross-Repository References

- Plan.md MUST specify target repository and paths explicitly
- Use repository name prefixes for clarity (e.g., `chat-backend/src/routes/`)
- Shared types are published via `@mentalhelpglobal/chat-types` npm package
- CI workflows are centralized in `chat-ci` and consumed via `uses:` references
- Document any cross-repository dependencies in plan.md

## Development Workflow

### Phase Gates

| Phase | Gate Criteria | Output |
|-------|---------------|--------|
| Specification | No unresolved [NEEDS CLARIFICATION]; checklist passes | `spec.md`, `checklists/requirements.md` |
| Planning | Constitution check passes; technical context complete | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| Tasks | All user stories mapped; dependencies documented | `tasks.md` |
| Implementation | Tests pass; code review complete; evidence captured | Updated source in `chat-client` |

### Quality Checkpoints

- **Spec Quality**: Technology-agnostic, measurable success criteria, bounded scope
- **Plan Quality**: Explicit tech stack, structure decisions documented, constitution compliance
- **Task Quality**: Checklist format (`- [ ] T### [P?] [US#] description with file path`)
- **Implementation Quality**: Tests green, AGENTS.md workflow followed, evidence in `evidence/`

## Governance

This constitution supersedes ad-hoc practices for all feature development orchestrated through `client-spec`.

### Amendment Process

1. Propose change via spec (use `/speckit.specify` with constitution amendment description)
2. Document rationale and impact on existing workflows
3. Update version according to semantic versioning:
   - MAJOR: Breaking changes to principles or workflows
   - MINOR: New principles or expanded guidance
   - PATCH: Clarifications and refinements
4. Propagate changes to dependent templates

### Compliance Verification

- All PRs/reviews MUST verify constitution compliance
- Checklist validation runs automatically via `/speckit.specify`
- Plan.md includes explicit Constitution Check section
- Non-compliance MUST be justified in Complexity Tracking section

### Reference Documents

- Backend conventions: `D:\src\MHG\chat-backend\CLAUDE.md`
- Frontend conventions: `D:\src\MHG\chat-frontend\CLAUDE.md`
- CI workflows: `D:\src\MHG\chat-ci\README.md`
- E2E tests: `D:\src\MHG\chat-ui\CLAUDE.md`
- Infrastructure: `D:\src\MHG\chat-infra\CLAUDE.md`
- Shared types: `D:\src\MHG\chat-types\package.json`
- Legacy monorepo: `D:\src\MHG\chat-client\AGENTS.md` (archived)

**Version**: 2.0.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-06
