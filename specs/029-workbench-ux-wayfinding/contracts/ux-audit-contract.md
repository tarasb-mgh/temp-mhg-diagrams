# Contract: Role-Based UX Audit Artifact Schema

## Purpose

Define the required structure for baseline and rerun UX audit outputs so evidence is comparable and acceptance checks are deterministic.

## Required Run Metadata

- `feature`: `029-workbench-ux-wayfinding`
- `run_type`: `baseline` or `rerun`
- `environment`:
  - `workbench_url`: `https://workbench.dev.mentalhelp.chat`
  - `api_url`: `https://api.dev.mentalhelp.chat`
- `sign_in_method`: `otp_fallback_dev`
- `started_at`: ISO-8601 datetime
- `finished_at`: ISO-8601 datetime
- `artifact_dir`: `artifacts/workbench-ux-audit-<timestamp>/`

## Baseline Run Metadata Contract Mapping

For baseline artifact `artifacts/workbench-ux-audit-20260312-232652/results.json`, map captured fields to contract fields as follows:

| contract field | source path | baseline value | notes |
| --- | --- | --- | --- |
| `feature` | static | `029-workbench-ux-wayfinding` | Fixed by feature scope. |
| `run_type` | static | `baseline` | This artifact is baseline only. |
| `environment.workbench_url` | `targetUrl` | `https://workbench.dev.mentalhelp.chat` | Direct mapping. |
| `environment.api_url` | `results[*].network[*].url` host | `https://api.workbench.dev.mentalhelp.chat` | Captured host differs from canonical API domain; treat as environment drift note. |
| `sign_in_method` | `results[*].actions` | `google_signin_attempted` | Non-compliant with FR-009; rerun must use OTP fallback. |
| `started_at` | artifact directory timestamp | `2026-03-12T23:26:52Z` | Derived from artifact folder naming convention. |
| `finished_at` | `generatedAt` | `2026-03-12T22:28:48.823Z` | Direct mapping from run output. |
| `artifact_dir` | static | `artifacts/workbench-ux-audit-20260312-232652/` | Direct mapping. |

### Mapping validation notes

- All required metadata fields are mappable.
- `sign_in_method` indicates baseline non-compliance with FR-009 and is intentionally retained as blocker evidence.
- API host mismatch must be recorded in rerun notes before acceptance.

## Required Role Matrix Payload

Exactly five role entries, one per role:

- `owner`
- `admin`
- `reviewer`
- `researcher`
- `group-admin`

Each role entry must contain:

- `role`
- `sign_in_status`: `passed` | `blocked`
- `blocker_reason` (required when blocked)
- `screenshots`:
  - `entry`
  - `menu`
  - `deep_flow`
  - `return_path`
- `flow_completion`:
  - `completed_without_manual`: boolean
  - `failed_attempts`: integer
- `notes`

## Required Findings Payload

Each finding object must contain:

- `id`
- `severity`: `P1` | `P2` | `P3`
- `role`
- `flow`
- `step`
- `impact`
- `evidence_path`
- `suspected_cause`
- `proposal`
- `owner_team`: `frontend` | `backend` | `product`
- `status`: `open` | `planned` | `implemented` | `validated`

## Navigation and Deep-Flow Contract Details

### Navigation Node Payload

Each captured navigation node for baseline/rerun must include:

- `node_id`: stable ID
- `label`: UI label text
- `level`: integer (`0`, `1`, `2`)
- `parent_node_id`: nullable string
- `roles_visible`: array of role enums
- `click_depth_from_home`: integer
- `is_ambiguous_label`: boolean

### Deep-Flow Payload

Each deep-flow record must include:

- `flow_id`
- `role`
- `entry_node_id`
- `steps`: ordered array of step objects:
  - `step_index`
  - `action_label`
  - `screen_context_visible` (boolean)
  - `next_step_hint_visible` (boolean)
- `return_path`:
  - `mechanism`: `back_button` | `breadcrumb` | `section_link`
  - `target_node_id`
  - `completed` (boolean)
- `dead_end_encountered` (boolean)

### Contract Constraints

1. `click_depth_from_home` must be `<= 3` for critical nodes.
2. Every deep flow must include a completed return-path check.
3. Any `is_ambiguous_label = true` node must create or link to a remediation item.
4. If `dead_end_encountered = true`, corresponding finding severity must be at least `P2`.

## Contextual Guidance Patterns

Each first-use guidance record must include:

- `guidance_id`
- `flow_id`
- `role`
- `pattern_type`: `purpose_hint` | `next_step_hint` | `consequence_visibility`
- `trigger_screen`
- `copy_text`
- `visibility_condition`
- `dismissible` (boolean)

Required behavior:

1. A `purpose_hint` must appear on first entry to complex sections.
2. A `next_step_hint` must be visible after successful completion of each major step.
3. `consequence_visibility` copy must appear before risky actions execute.

## Risky-Action Guardrails

Each risky action contract entry must include:

- `action_id`
- `screen`
- `risk_level`: `medium` | `high`
- `confirmation_required` (boolean)
- `confirmation_copy`
- `rollback_path_visible` (boolean)
- `post_success_route`

Guardrail constraints:

1. `risk_level = high` requires explicit confirmation with consequence copy.
2. `rollback_path_visible` must be `true` for all risky actions.
3. `post_success_route` must return users to a known section context (no dead end).

## Acceptance Evaluation Rules

1. Rerun must fail if any role is blocked.
2. Rerun must fail if any P1 wayfinding/discoverability blocker remains unresolved.
3. "Without manual guidance" is true only when:
   - no external docs/chat help used
   - only in-product cues used
   - failed attempts per flow <= 1
4. SC-003 passes only if >= 80% of tested users meet rule (3) across 3 critical flows.
5. Evidence retention for run artifacts is 90 days.

## Storage and Retention

- Store raw screenshots/logs/results in `artifacts/workbench-ux-audit-<timestamp>/`.
- Preserve artifacts for 90 days from run completion.
