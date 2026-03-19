# Content Contract: Research Ethics & Inter-Rater Reliability Report

**Target Confluence Page**: "Research Ethics & Inter-Rater Reliability Report"
**Parent**: Compliance Documentation
**Space**: UD (User Documentation)
**Format**: Markdown

---

## Page Content Template

```markdown
# Research Ethics & Inter-Rater Reliability Report

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Created** | 2026-03-15 |
| **Last Updated** | 2026-03-15 |
| **Owner Role** | ML Engineering Team (technical record) / Clinical Governance Lead (review) |
| **Review Schedule** | Quarterly — next review: 2026-06-15 |
| **Standards** | ICH E9 (Statistical Principles for Clinical Trials) / GCP (Good Clinical Practice) — applied as equivalent-standard frameworks for annotation and model validation methodology |
| **Note** | This document covers the annotation pipeline and model quality methodology only. Clinical trial registration and informed consent flows are out of scope. |

---

## Scope Statement

This document covers the inter-rater reliability (IRR) methodology for transcript annotation, the model performance evaluation framework, and the transcript sampling pipeline controls. In scope: annotation blinding, Cohen's κ and Fleiss' κ computation, bootstrap confidence intervals, model performance metrics with clinical cost asymmetry, and transcript sampling pipeline (stratified sampling, PII redaction, deterministic seed). Out of scope: clinical trial registration, informed consent for research participants, and the 9-class taxonomy label definitions (clinical lead decision).

---

## Regulation-to-Implementation Mapping

| Area/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status |
|---|---|---|---|---|---|
| Annotation Blinding (ICH E9 §3.4) | Blind annotators to each other's labels until both submit to prevent anchoring bias | Annotation system enforces submission-gated visibility | Annotators cannot view peer labels until both have submitted. Side-by-side adjudication view is unlocked post-submission. `annotations` table schema: `annotator_id`, `label_category`, `confidence`, `adjudicated_label`, `is_ground_truth` — annotators query only their own rows until adjudication phase | `specs/030-non-therapy-technical-backlog/spec.md: FR-030, FR-031` | Compliant |
| Transcript Sampling Pipeline (ICH E9 §3.1) | Sampling must be reproducible, representative, and free from bias | Stratified sampling with deterministic random seed and PII redaction | Transcript sampling (FR-032) is stratified by: flag_type, session_length, region, severity band. Random seed is logged for reproducibility. PII auto-redaction applied to all transcripts before export to annotators. Sampling parameters are auditable from the seed value | `specs/030-non-therapy-technical-backlog/spec.md: FR-032` | Compliant |
| Cohen's κ — Pairwise Reliability (ICH E9 §3.4) | Quantify agreement between annotator pairs using validated methodology | Pairwise Cohen's κ (unweighted and weighted variants) with 1,000-iteration bootstrap CI | Cohen (1960) κ formula implemented for pairwise annotator agreement per label category. Linear-weighted κ and quadratic-weighted κ computed for ordinal categories. 1,000-iteration bootstrap CI provides uncertainty bounds. κ < 0.6 threshold triggers Clinical Lead alert | `specs/030-non-therapy-technical-backlog/spec.md: FR-033`; unit test with known input (manual reference calculation within ±0.001) | Compliant |
| Fleiss' κ — Multi-Rater Reliability | Quantify agreement across ≥3 annotators | Fleiss' κ for sessions with 3+ annotators | Fleiss' κ implementation handles variable numbers of raters per transcript. Computed per label category and aggregate. Consistent with the pairwise Cohen's κ methodology | `specs/030-non-therapy-technical-backlog/spec.md: FR-033` | Compliant |
| Bootstrap Confidence Intervals (ICH E9 §8.1) | Report uncertainty bounds on reliability estimates | 1,000-iteration bootstrap CI on all κ estimates | Stratified bootstrap resampling (sampling with replacement from annotator pairs). 1,000 iterations produce 95% CI via percentile method. CI width used as secondary quality indicator alongside point estimate | `specs/030-non-therapy-technical-backlog/spec.md: FR-033` | Compliant |
| Model Performance Metrics (ICH E9 §5.3) | Report sensitivity, specificity, and clinically appropriate metrics | F-beta with β=4.47 for 20:1 false-negative to false-positive cost asymmetry | Sensitivity, specificity, PPV, NPV, FNR, F1, and F-beta (β=4.47) computed per label category and aggregate. β=4.47 reflects the 20:1 cost asymmetry: missing a genuine risk signal (FN) is 20× more harmful than a false alert (FP) in a mental health context. Rationale: √20 ≈ 4.47 (harmonic mean weighting for recall emphasis) | `specs/030-non-therapy-technical-backlog/spec.md: FR-034` | Compliant |
| Confusion Matrices (ICH E9 §5.5) | Report full confusion matrix per label category | Per-category and aggregate confusion matrices | Confusion matrix computed for each of the label categories, enabling per-class performance analysis. Supports identification of systematic annotation disagreement patterns | `specs/030-non-therapy-technical-backlog/spec.md: FR-033, FR-034` | Compliant |

---

## κ Threshold Rationale

| κ Range | Interpretation | Action |
|---|---|---|
| < 0.20 | Slight agreement | STOP — suspend annotation; root cause investigation |
| 0.20–0.39 | Fair agreement | Warning — annotator calibration session required |
| 0.40–0.59 | Moderate agreement | Monitor — acceptable for exploratory annotation |
| 0.60–0.79 | Substantial agreement | Target range — proceed |
| ≥ 0.80 | Almost perfect agreement | Optimal |

**Alert threshold**: κ < 0.6 triggers an automated alert to the Clinical Lead. This threshold is consistent with Landis & Koch (1977) criteria for "substantial agreement" as the minimum acceptable for clinical AI model validation.

---

## Cost Asymmetry Rationale (β=4.47)

In a mental health risk assessment context, a false negative (missing a genuine risk signal) results in a vulnerable individual not receiving intervention — a directly harmful outcome. A false positive (flagging a non-at-risk individual) results in unnecessary supervisor review — a manageable overhead cost.

The 20:1 cost ratio (FN cost : FP cost) is a conservative clinical governance estimate. The F-beta formula weights recall (sensitivity) relative to precision. With β=4.47 (√20), the F-beta metric assigns recall 20× the weight of precision, ensuring model selection optimises for safety first.

---

## Compliance Gap Register

| Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date |
|---|---|---|---|---|---|
| Annotation Taxonomy | 9-class taxonomy label definitions not yet finalised (clinical lead decision required) | Medium | Clinical Governance Lead | Annotation schema deployed; blinding and κ infrastructure ready; labels configurable | 2026-05-01 |
| Ethics Board Registration | Formal ethics board registration for annotation research not completed | Medium | Clinical Governance Lead | Annotation is on de-identified transcripts (PII-redacted); GDPR consent covers data use for model improvement | 2026-06-01 |

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-03-15 | Engineering Team | Initial publication |
```
