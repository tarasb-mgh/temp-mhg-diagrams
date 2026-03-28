# Contributing to the Workbench Regression Suite

## When to Add Tests

- **After a feature ships** that adds or changes workbench UI behavior
- **After a bug fix** that addresses a user-facing regression
- **After an i18n update** that adds new translation keys

## How to Add Tests

### 1. Identify the module

Find the YAML file that covers the feature area:

| Module | File | Covers |
|--------|------|--------|
| Auth | `01-auth.yaml` | Login, logout, session, role-based access |
| Navigation | `02-navigation.yaml` | Sidebar, breadcrumbs, group selector, language, PII toggle |
| Review Queue | `03-review-queue.yaml` | Queue tabs, filtering, pagination, session cards |
| Review Session | `04-review-session.yaml` | Rating, submit, comments, tags, back navigation |
| Review Dashboards | `05-review-dashboards.yaml` | Dashboards, reports, escalations, config |
| Safety Flags | `06-safety-flags.yaml` | Elevated sessions, flag resolution, escalation |
| Survey Schemas | `07-survey-schemas.yaml` | Schema CRUD, editor, publish, clone, archive |
| Survey Instances | `08-survey-instances.yaml` | Instance CRUD, responses, deployment |
| User Management | `09-user-management.yaml` | User list, profile, approvals, tester tags |
| Group Management | `10-group-management.yaml` | Groups, members, invitations, group-scoped views |
| Privacy | `11-privacy-gdpr.yaml` | PII masking, export, erasure |
| Security | `12-security-admin.yaml` | RBAC, permissions, feature flags |
| Settings | `13-settings.yaml` | Preferences, admin settings |
| i18n | `14-i18n.yaml` | Locale switching, translation completeness |
| Responsive | `15-responsive.yaml` | Mobile, tablet, desktop layouts |
| Cross-cutting | `16-cross-cutting.yaml` | PWA, empty states, error monitoring |

If the feature area doesn't fit any existing module, create a new one following the naming convention: `NN-feature-area.yaml`.

### 2. Follow the test case schema

Each test case is a YAML object:

```yaml
- id: XX-NNN          # Module prefix + next number (e.g., RQ-015)
  title: "..."        # Human-readable test name
  priority: P0-P3     # P0=smoke, P1=standard, P2=full, P3=optional
  tags: [...]         # Ad-hoc labels
  role: owner         # Account role (owner, moderator, researcher, qa, user, group_admin)
  viewport: default   # Or { width: N, height: N }
  prerequisites: []   # Human-readable conditions
  depends_on: []      # Test IDs that must pass first

  steps:
    - action: browser_navigate
      params:
        url: "${workbench_url}/path"
      expect: "Description of expected state"

    - action: browser_snapshot
      assert:
        - element_visible: "description of element"

    - action: evidence_capture
      assert:
        - no_unexpected_console_errors: true
        - no_unexpected_network_failures: true

  pass_criteria:
    - "Clear pass condition"
  error_signatures:
    - pattern: "regex or substring"
      severity: critical|high|medium|low
      meaning: "What this error indicates"
```

### 3. Assign priority

| Priority | Use for | Example |
|----------|---------|---------|
| P0 | Critical path — if this fails, the app is broken | Login, main page load, core CRUD |
| P1 | Standard workflows — should work after every deploy | Review rating, survey creation, user search |
| P2 | Edge cases and secondary flows | Pagination, filter combos, responsive edge cases |
| P3 | Exploratory/optional — nice to verify but not blocking | PWA banner, loading skeletons |

### 4. ID conventions

- Use the module prefix: `AUTH-`, `NAV-`, `RQ-`, `RS-`, `RD-`, `SF-`, `SS-`, `SI-`, `UM-`, `GM-`, `PV-`, `SA-`, `ST-`, `I18N-`, `RL-`, `CC-`
- Number sequentially from the last ID in the module (e.g., if last is `RQ-014`, next is `RQ-015`)
- IDs must be unique across ALL modules

## When to Update Tests

- When a feature **changes behavior** that existing tests assert against (e.g., button label changes, new required field)
- When a **known issue** is fixed and the test should now pass (remove from `known_issues` in `_config.yaml`)

## When to Remove Tests

- When a feature is **deprecated and removed** from the UI
- When a test is **permanently flaky** with no fix possible — document the reason in CHANGELOG.md

## Validation

After any change, verify:

```bash
python -c "
import yaml, glob, os
ids = []
for f in sorted(glob.glob('regression-suite/[0-9]*.yaml')):
    with open(f, encoding='utf-8') as fh:
        data = yaml.safe_load(fh)
    for t in data.get('tests', []):
        ids.append(t['id'])
dupes = [x for x in set(ids) if ids.count(x) > 1]
print(f'Total: {len(ids)} tests, Unique: {len(set(ids))} IDs')
if dupes: print(f'DUPLICATES: {dupes}')
else: print('No duplicates')
"
```

## Record Changes

After adding, updating, or removing tests, add an entry to `CHANGELOG.md`.
