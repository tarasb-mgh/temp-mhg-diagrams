# Security Requirements Quality Checklist: Reviewer Review Queue

**Purpose**: Unit-test the security requirements written in `spec.md` for completeness, clarity, consistency, measurability, and coverage. NOT a verification that the implementation works — a quality gate on the requirements themselves before `/speckit.plan`.
**Created**: 2026-04-16
**Feature**: [spec.md](../spec.md)
**Audience**: PR reviewer + security reviewer (release-gate depth)

## Authentication & Session Management

- [ ] CHK001 Are 2FA requirements unambiguous about which method applies in which environment? [Clarity, Spec §FR-004]
- [ ] CHK002 Is the dev/staging email-OTP delivery channel (browser console) explicitly bounded to non-production environments? [Consistency, Spec §FR-004, Clarifications Round 1]
- [ ] CHK003 Are TOTP enrolment, recovery, and rotation requirements specified, or is enrolment treated as out of scope? [Gap, Spec §FR-004]
- [ ] CHK004 Is the inactivity timeout default (30 min) and its admin-configurable nature unambiguously specified? [Clarity, Spec §FR-005]
- [ ] CHK005 Are the post-timeout state-preservation requirements (draft survives logout) consistent with the autosave model? [Consistency, Spec §FR-005, §FR-031..§FR-033]
- [ ] CHK006 Are requirements for failed sign-in handling (lockout thresholds, IP-based throttling) defined? [Gap]
- [ ] CHK007 Is the audit-log requirement for failed login attempts unambiguous about which fields are recorded? [Completeness, Spec §FR-049, §US-8]

## Authorization (RBAC) and Data Isolation

- [ ] CHK008 Are server-side RBAC requirements stated for every Reviewer-facing endpoint, not only the UI? [Coverage, Spec §FR-003, §FR-046, §FR-048]
- [ ] CHK009 Is the rule that "bypassing the UI MUST NOT grant access" measurable through specific access patterns? [Measurability, Spec §FR-003]
- [ ] CHK010 Are Space-based isolation rules consistent across queue, Reports, session detail, language filter, and the bell list? [Consistency, Spec §FR-010..§FR-010b, §FR-043]
- [ ] CHK011 Are requirements for cross-Reviewer data leak prevention specified at the API layer for tags, flags, ratings, comments, and notifications individually? [Completeness, Spec §FR-048]
- [ ] CHK012 Is the behaviour on URL-tampering (manually typed session ID outside the Reviewer's Spaces) explicitly defined? [Coverage, Spec §US-6, §FR-010]
- [ ] CHK013 Is the rule for newly-added / newly-removed Space membership unambiguous about latency and visibility? [Clarity, Spec §EC-09a, §EC-09b]
- [ ] CHK014 Are notification-payload visibility rules consistent with Space isolation (no leak across Spaces)? [Consistency, Gap]

## Input Validation and CSRF / XSS Protection

- [ ] CHK015 Are server-side validation requirements specified for every Reviewer input (rating score 1–10, criterion ID, comment, validated answer, tag attach payload, Red Flag description, change-request reason, filter values)? [Completeness, Gap]
- [ ] CHK016 Are XSS-safe rendering requirements stated for free-text Reviewer fields (comments, validated answers, tag descriptions, Red Flag descriptions, Reviewer notification text)? [Gap]
- [ ] CHK017 Are CSRF-protection requirements stated for every state-changing Reviewer endpoint (autosave, submit, change-request send, notification dismiss)? [Gap]
- [ ] CHK018 Are upload limits, charset, and length caps for free-text fields explicitly defined? [Gap]

## PII and Sensitive Data Protection

- [ ] CHK019 Are PII categories enumerated in `FR-047c` exhaustive enough for the clinical chat domain (do they cover medical IDs, DOB, geo, employer, names, emails, phones, addresses, all expected categories)? [Completeness, Spec §FR-047c]
- [ ] CHK020 Are the prohibitions in `FR-047d` (no toggle, no reveal, no hover-reveal, no console leak, no bypass via copy/export) phrased as testable absolutes? [Measurability, Spec §FR-047d]
- [ ] CHK021 Is the requirement that PII masking happens BEFORE the payload reaches the Reviewer client unambiguous about the layer of enforcement? [Clarity, Spec §FR-047c]
- [ ] CHK022 Are requirements specified for the failure mode when the PII detector misses a known pattern? [Coverage, Spec §FR-047f]
- [ ] CHK023 Are reveal-on-demand prohibitions consistent across every Reviewer surface mentioned (transcript, search, copy, export)? [Consistency, Spec §FR-047d, §FR-046]
- [ ] CHK024 Are encryption-at-rest and encryption-in-transit requirements stated, or are they assumed inherited from the platform? [Gap]

## Audit Logging & Compliance

- [ ] CHK025 Is every state-changing Reviewer event listed (rating CRUD, tag attach/detach, Red Flag raise/clear, change-request, login success/fail, logout, notification.read, settings change) covered by an audit-log requirement? [Coverage, Spec §FR-049, §FR-050a]
- [ ] CHK026 Are Audit Log fields (timestamp, user ID, role, IP, target, event type, legal_hold) sufficient for incident investigation? [Completeness, Spec §FR-049, §FR-050a, §Key Entities]
- [ ] CHK027 Is the append-only constraint stated as a hard prohibition on UI AND API mutation paths (no admin override)? [Consistency, Spec §FR-050]
- [ ] CHK028 Is the 5-year retention split (hot 0–12 mo, warm 12–36 mo, cold 36–60 mo) precisely specified including the cold-tier query latency expectation? [Clarity, Spec §FR-050a]
- [ ] CHK029 Is the automated-purge audit-entry requirement (sequence ID + count + window) specified clearly enough to verify? [Measurability, Spec §FR-050b]
- [ ] CHK030 Is the `legal_hold` pass-through field's semantics (NEVER purge, no Reviewer-side toggle) unambiguous? [Clarity, Spec §FR-050b]
- [ ] CHK031 Are GDPR right-to-be-forgotten interactions with Audit Log retention reconciled (or explicitly deferred to upstream)? [Gap, Compliance]

## Threat Model & Failure Modes

- [ ] CHK032 Are requirements specified for Audit Log API outage (current dev bug — "Failed to query audit log") at the Reviewer-facing surface? [Gap, §Dependencies]
- [ ] CHK033 Are requirements for offline mode and queued IndexedDB entries safe from cross-account data leakage on shared devices? [Gap, Spec §FR-031b]
- [ ] CHK034 Is multi-tab reconciliation (FR-034a) safe against state injection from a maliciously-crafted second tab in the same browser session? [Coverage, Gap]
- [ ] CHK035 Are concurrent-edit conflict semantics (last-blur-wins per field) acceptable from a clinical-record-integrity perspective? [Acceptance Criteria, Spec §FR-034a, §EC-20]
- [ ] CHK036 Is the threat model documented or referenced (which threats are explicitly in/out of scope)? [Gap, Traceability]
- [ ] CHK037 Are session-token storage and theft-mitigation requirements stated? [Gap]

## Dependencies & Trust Boundaries

- [ ] CHK038 Are trust assumptions about the Tag Center service (incl. soft-delete propagation latency) documented? [Assumption, Spec §FR-021b, §Dependencies]
- [ ] CHK039 Are trust assumptions about the Spaces service (membership churn latency, deletion semantics) documented? [Assumption, Spec §FR-010, §Dependencies]
- [ ] CHK040 Are trust assumptions about the email infrastructure (no PII leak in Supervisor emails about flagged sessions) explicit? [Gap, Spec §FR-028]

## Notes

- 40 items.
- Mark off as resolved during spec review or planning; flag any FAIL items as blockers before `/speckit.plan` proceeds further.
