# Content Contract: Clinical Data & Safety Compliance Report

**Target Confluence Page**: "Clinical Data & Safety Compliance Report"
**Parent**: Compliance Documentation
**Space**: UD (User Documentation)
**Format**: Markdown

---

## Page Content Template

```markdown
# Clinical Data & Safety Compliance Report

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Created** | 2026-03-15 |
| **Last Updated** | 2026-03-15 |
| **Owner Role** | Engineering Team (technical record) / Clinical Governance Lead (review) |
| **Review Schedule** | Quarterly — next review: 2026-06-15 |
| **Regulation** | HIPAA-equivalent clinical data standards (applied as equivalent-standard framework) |
| **Note** | The platform is not subject to HIPAA as a US regulation. These controls are implemented to HIPAA-equivalent standard as required by enterprise clinical governance frameworks and NHS/HSE procurement guidelines. |

---

## Scope Statement

This document covers the handling of sensitive mental health assessment data (PHQ-9, GAD-7, PCL-5, WHO-5 instruments) and clinical risk flag routing. In scope: assessment data storage, AI safety filtering layer, supervisor RBAC, risk flag audit trail, and the k=10 anonymity suppression mechanism. Out of scope: clinical content (questionnaire wording, score interpretation thresholds) — those are governed by instrument licensing and clinical lead configuration, not engineering controls.

---

## Regulation-to-Implementation Mapping

| Area/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status |
|---|---|---|---|---|---|
| Minimum Necessary Standard | Access to protected health information must be limited to the minimum necessary | AI model receives severity band labels only — not numeric scores | Score context injection (FR-023): `assessment_scores.severity_band` label (e.g., "moderate") and trajectory direction only are injected into the AI system prompt. Raw numeric PHQ-9/GAD-7/PCL-5/WHO-5 scores are never passed to the AI model. 200ms timeout with fail-open behaviour on error | `specs/030-non-therapy-technical-backlog/spec.md: FR-023`; post-generation filter implementation | Compliant |
| Audit Controls — Append-Only | Health records must be protected against unauthorised modification | `assessment_sessions`, `assessment_items`, `assessment_scores` tables are append-only | PostgreSQL triggers enforce no UPDATE/DELETE on assessment tables. Erasure exception: only the GDPR erasure cascade (FK nullification) is permitted, not arbitrary deletion. All assessment rows persist for aggregate integrity | `specs/030-non-therapy-technical-backlog/spec.md: FR-015`; database trigger evidence | Compliant |
| Access Controls — RBAC | Access to health information must be role-based and cohort-scoped | `supervisor_cohort_assignments` table gates all supervisor queries | All supervisor analytics queries include `WHERE cohort_id IN (SELECT cohort_id FROM supervisor_cohort_assignments WHERE supervisor_id = ?)` guard. API layer enforces 403 for role violations — no client-side only enforcement | `specs/030-non-therapy-technical-backlog/spec.md: FR-027`; access control integration tests | Compliant |
| Access Controls — k=10 Anonymity | Aggregate health data must not permit re-identification | k=10 row suppression in all cohort-level analytics queries | All analytics endpoints suppress result rows where `cohort_user_count < 10`. Guard is server-side, not client-side. Prevents inference attacks on small cohorts | `specs/030-non-therapy-technical-backlog/spec.md: FR-026` | Compliant |
| AI Safety Filtering — Post-Generation Filter | AI-generated clinical content must be reviewed before delivery | Server-side regex + keyword filter applied to all AI responses before delivery to user | Post-generation filter (FR-022) scans for: numeric scores adjacent to instrument names (e.g., "PHQ-9: 18"), diagnostic terms, clinical urgency language. Flagged responses logged and replaced with pre-approved fallback string. Filter runs server-side only — client never receives unfiltered response | `specs/030-non-therapy-technical-backlog/spec.md: FR-022` | Compliant |
| AI Safety Filtering — Fail-Open | AI filter must not block user access on infrastructure failure | Score context injection fails open (no context injected) on timeout | If the score context injection service does not respond within 200ms, the AI session proceeds without score context — user is not blocked. Fail-open is preferable to fail-closed (denying mental health support access) for safety reasons | `specs/030-non-therapy-technical-backlog/spec.md: FR-023` | Compliant |
| AI Safety Filtering — Session Cache | Score context must not be stale within a session | Per-session, per-user score context cache invalidated on new assessment completion | Session-level cache (FR-024): cache key = `(pseudonymous_user_id, session_id)`. Invalidated when `assessment_session.status = complete` event fires. Prevents AI from receiving outdated severity context within an active session | `specs/030-non-therapy-technical-backlog/spec.md: FR-024` | Compliant |
| Risk Flag Audit Trail | Risk flag creation and resolution must be auditable | Risk flags have `resolved_by` supervisor FK and `resolved_at` timestamp | Risk flag deduplication (FR-021): existing Urgent flags updated vs. new Critical flags always created. `resolved_by` FK links to supervisor who resolved; `resolved_at` records timestamp. Risk flag lifecycle is fully auditable in the database | `specs/030-non-therapy-technical-backlog/spec.md: FR-021` | Compliant |
| Risk Flag — Adaptive Scheduling | High-risk users must be re-assessed more frequently | Adaptive assessment scheduling based on severity band | `assessment_schedule` table with Cloud Tasks scheduler (FR-019): severe → 14-day interval, moderate → 28-day, mild → 35-day. `deferral_count` tracked. `scheduler_paused` flag for clinical override | `specs/030-non-therapy-technical-backlog/spec.md: FR-019`; Cloud Tasks queue: `assessment-scheduler-dev` | Compliant |

---

## Compliance Gap Register

| Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date |
|---|---|---|---|---|---|
| AI Safety — Fallback Strings | Approved fallback strings for filtered AI responses not yet defined (therapy team sign-off required) | Medium | Clinical Governance Lead | Filter infrastructure deployed; "response unavailable" generic fallback active | 2026-05-01 |
| Risk Thresholds | Default `risk_thresholds` table values not yet set (clinical lead decision required) | Medium | Clinical Governance Lead | Schema deployed; thresholds configurable; no assessment scoring active until clinical lead configures | 2026-05-01 |

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-03-15 | Engineering Team | Initial publication |
```
