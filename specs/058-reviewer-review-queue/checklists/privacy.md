# Privacy Requirements Quality Checklist: Reviewer Review Queue

**Purpose**: Unit-test the privacy / GDPR requirements written in `spec.md` for completeness, clarity, consistency, measurability, and coverage. NOT an implementation verification — a quality gate on the requirements themselves before `/speckit.plan`.
**Created**: 2026-04-16
**Feature**: [spec.md](../spec.md)
**Audience**: PR reviewer + privacy/compliance reviewer (release-gate depth)

## PII Detection & Masking

- [ ] CHK001 Are the PII categories enumerated in `FR-047c` (names, emails, phones, addresses, medical IDs, DOB, geo, employer/school refs, inline numeric IDs) sufficient for clinical chat in EU + UA contexts? [Completeness, Spec §FR-047c]
- [ ] CHK002 Is the placeholder pattern `[REDACTED:type]` defined precisely enough to be uniformly applied (case sensitivity, type taxonomy, edge cases like names embedded in URLs)? [Clarity, Spec §FR-047c]
- [ ] CHK003 Is the requirement "PII detector runs on the SERVER side before payload reaches client" stated with no client-side fallback path? [Consistency, Spec §FR-047c, §FR-047d]
- [ ] CHK004 Is the failure-mode requirement (PII detector misses a known pattern) classified with a severity level and an escalation channel? [Coverage, Spec §FR-047f]
- [ ] CHK005 Are requirements for PII inside Reviewer-authored fields (validated answer, criterion comment, tag comment, Red Flag description, change-request reason) defined — does the Reviewer's own input also pass the detector before persistence? [Gap]

## Reviewer-Surface Prohibitions

- [ ] CHK006 Is the prohibition "no PII Masking toggle" measurable as a UI absence-test? [Measurability, Spec §FR-047d]
- [ ] CHK007 Is the prohibition on hover-reveal / click-reveal / tooltip-reveal explicit and exhaustive across every Reviewer surface? [Coverage, Spec §FR-047d]
- [ ] CHK008 Is the prohibition on "console output of unmasked payload" measurable through automated detection? [Measurability, Spec §FR-047d]
- [ ] CHK009 Is the prohibition on "deanonymisation API endpoint reachable with Reviewer's token" verifiable through a focused E2E? [Measurability, Spec §SC-013p]
- [ ] CHK010 Are requirements specified to suppress browser-level autocomplete / form-fill from caching unmasked input on Reviewer surfaces? [Gap]

## Data Lifecycle & Retention

- [ ] CHK011 Are retention rules clear for Reviewer-authored content (ratings, tag comments, Red Flag descriptions, change-request reasons)? [Gap]
- [ ] CHK012 Is the 5-year Audit Log retention split (hot/warm/cold) reconciled with GDPR right-to-erasure for Reviewer accounts? [Consistency, Spec §FR-050a]
- [ ] CHK013 Is the `legal_hold` pass-through field documented in a way that future GDPR erasure flows can integrate without breaking the audit chain? [Coverage, Spec §FR-050b]
- [ ] CHK014 Are retention rules for the IndexedDB offline queue (FR-031b) defined — is queued PII payload purged on logout or after sync? [Gap, Spec §FR-031b]
- [ ] CHK015 Are session draft retention rules (UNFINISHED reviews left for months by deactivated users) specified? [Coverage, Spec §EC-09]

## Cross-Account & Multi-Device Privacy

- [ ] CHK016 Is the rule "Reviewer A MUST NOT see Reviewer B's data" extended to notification payloads, change-request reasons, and tag comments? [Consistency, Spec §FR-048]
- [ ] CHK017 Are requirements specified for the case where multiple Reviewers use the same physical device sequentially (data residue in IndexedDB / browser cache between sign-ins)? [Gap, Spec §FR-031b]
- [ ] CHK018 Is the multi-tab reconciliation (FR-034a) safe against PII leak via the "competing value visible on hover" indicator from EC-20? [Coverage, Spec §EC-20]

## Compliance & Legal Basis

- [ ] CHK019 Is the legal basis for processing chat-session data by Reviewers documented or referenced (consent vs legitimate interest)? [Gap, Compliance]
- [ ] CHK020 Are GDPR Article 32 (security of processing) requirements addressed in the spec? [Gap, Compliance]
- [ ] CHK021 Are data-subject-access-request (DSAR) rules reconciled with the Reviewer's read-only access to anonymised data? [Gap, Compliance]
- [ ] CHK022 Are data-residency requirements (EU vs other regions) stated, or assumed inherited from the platform? [Gap, Compliance]
- [ ] CHK023 Are sub-processor disclosures required (PII detector vendor, email provider) considered in scope or out? [Gap, Compliance]

## Audit & Accountability

- [ ] CHK024 Is every read of an unmasked payload (by higher-privilege roles, even though out of scope here) audit-logged so the Reviewer scope can rely on the trail? [Coverage, Gap, Spec §FR-047e]
- [ ] CHK025 Are requirements specified for the Audit Log itself NOT containing unmasked PII in target / payload fields? [Gap, Spec §FR-049, §FR-050a]
- [ ] CHK026 Are requirements specified for browser-level error reports / Sentry-style telemetry NOT carrying unmasked transcripts? [Gap]
- [ ] CHK027 Are requirements specified for Playwright trace artefacts (used in E2E) NOT capturing unmasked PII? [Gap, Spec §SC-013p]

## Notes

- 27 items.
- Outstanding items map directly to specific GDPR risks; resolve before merge.
