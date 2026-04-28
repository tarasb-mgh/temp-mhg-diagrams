# Implementation Plan: 061-mc-64-tile-label

**Branch**: `061-mc-64-tile-label` | **Date**: 2026-04-28 | **Spec**: [`spec.md`](./spec.md)
**Jira Epic**: MTB-1604 | **Bug**: MC-64 | **Predecessor Epic**: MTB-1546 (Feature 060)

## Summary

Rename the i18n key `dashboard.stats.pendingReview` → `dashboard.stats.pendingModeration` across the workbench-frontend en/uk/ru locale files and update the single consumer (`Dashboard.tsx:176`). Drop regression test RQ-002a (intrinsically wrong assertion) and add RQ-002b (label-correctness check). No chat-backend change. ~30 minutes engineer-time.

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-first | ✅ | Brainstorming → design doc → spec → plan chain followed. |
| II. Multi-repo coordination | ✅ | Two repos touched (workbench-frontend, client-spec). chat-backend untouched. |
| III. Test-aligned coverage | ✅ | RQ-002b is the new regression contract. Existing 0c4dd76+ frontend type-check + lint covers code. |
| IV. PR-cycle gates | ✅ | Two PRs (workbench-frontend → develop, client-spec → main). Owner-approval merge per prior pattern. |
| V. Backward compatibility | ✅ | i18n key rename has no external consumers. Data flow unchanged. |
| X. Jira traceability | ✅ | Epic MTB-1604 created. Per-task issues created via /speckit.taskstoissues during /mhg.tasks. |
| XI. Documentation | ✅ | Spec + design doc + plan + (forthcoming) tasks. No User Manual or Release Notes update needed (cosmetic label fix). |

## Tech Context

- **Stack** (workbench-frontend): React 18 + Vite + react-i18next; locale files at `src/locales/{en,uk,ru}.json`. Already part of the develop branch the prior 060 work landed on.
- **Stack** (client-spec): YAML regression-suite executed by AI-agent runner via Playwright MCP tools.
- **chat-backend**: not modified. The `getTeamStats` patch from `chat-backend@c7648ac` stays in.

## Project Structure

```
workbench-frontend/
├── src/
│   ├── locales/
│   │   ├── en.json   # rename dashboard.stats.pendingReview key
│   │   ├── uk.json   # rename dashboard.stats.pendingReview key
│   │   └── ru.json   # rename dashboard.stats.pendingReview key
│   └── features/workbench/
│       └── Dashboard.tsx   # update t() call at line 176

client-spec/
├── regression-suite/
│   └── 03-review-queue.yaml    # drop RQ-002a, add RQ-002b
└── specs/061-mc-64-tile-label/
    ├── spec.md
    ├── plan.md (this file)
    ├── tasks.md
    └── checklists/requirements.md
```

## Phasing

| # | Phase | Goal | Eff. | Output |
|---|-------|------|------|--------|
| 1 | workbench-frontend i18n rename + tsx reference | Make the tile label honest under all 3 locales | ~10 min | PR to `workbench-frontend@develop` |
| 2 | client-spec regression-suite swap | Drop the wrong assertion, add the correct one | ~10 min | PR to `client-spec@main` |
| 3 | Verify | Re-run RQ-002b on dev after the workbench-frontend deploy lands; confirm 0 stale refs to the old i18n key | ~10 min | Updated regression results + Jira closure |

Phases 1 and 2 are independent and may proceed in parallel. Phase 3 requires Phase 1 deployed to dev + Phase 2 merged to main.

## Risks

- **Locale review**: native-speaker review of the new uk/ru strings is not blocking but recommended. Strings mirror the existing `awaitingModeration` subtitle phrasing and are direct translations of the English; risk is low.
- **i18n key collision**: `pendingModeration` is a new key path. Confirmed via grep: not currently used in any locale file.
- **Stale bundle window**: during workbench-frontend deploy rollout, a user holding a stale tab MAY briefly see the literal i18n key string. Self-resolves on refresh. Acceptable.

## Out of Scope (explicit)

- chat-backend changes — `getTeamStats` patch from Feature 060 stays in.
- Removing the tile entirely (rejected approach C).
- Adding a new "review-eligible pending count" admin endpoint (rejected approach B).
- Renaming `pendingReview` keys in non-`dashboard.stats` namespaces.
