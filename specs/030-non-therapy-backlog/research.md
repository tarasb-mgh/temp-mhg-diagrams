# Research: Non-Therapy Technical Backlog

**Branch**: `030-non-therapy-backlog` | **Date**: 2026-03-15
**Purpose**: Resolve all technical unknowns before Phase 1 design

---

## R-01 — Jacobson-Truax RCI & PostgreSQL Materialised View

**Decision**: Implement RCI as a computed column in a PostgreSQL materialised view using the Jacobson-Truax formula.

**Formula**:
```
RCI = (score₂ - score₁) / SE_diff
where SE_diff = SEM × √2
```

Standard error of measurement values (from published norms):
- PHQ-9: SEM = 2.1
- GAD-7: SEM = 2.0
- PCL-5: SEM = 5.0
- WHO-5: SEM = 7.0 (confirm with Clinical Lead — see spec open question)

**PostgreSQL implementation**:
```sql
CREATE MATERIALIZED VIEW score_trajectories AS
SELECT
  s.pseudonymous_user_id,
  s.instrument_type,
  s.total_score,
  s.administered_at,
  AVG(s.total_score) OVER (
    PARTITION BY s.pseudonymous_user_id, s.instrument_type
    ORDER BY s.administered_at
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ) AS rolling_30d_mean,
  (s.total_score - LAG(s.total_score) OVER (
    PARTITION BY s.pseudonymous_user_id, s.instrument_type
    ORDER BY s.administered_at
  )) / (
    CASE s.instrument_type
      WHEN 'PHQ9' THEN 2.1 * SQRT(2)
      WHEN 'GAD7' THEN 2.0 * SQRT(2)
      WHEN 'PCL5' THEN 5.0 * SQRT(2)
      WHEN 'WHO5' THEN 7.0 * SQRT(2)
    END
  ) AS rci,
  CASE
    WHEN s.instrument_type = 'PHQ9' AND (LAG(s.total_score) OVER (...) - s.total_score) >= 5 THEN true
    WHEN s.instrument_type = 'GAD7' AND (LAG(s.total_score) OVER (...) - s.total_score) >= 4 THEN true
    WHEN s.instrument_type = 'PCL5' AND (LAG(s.total_score) OVER (...) - s.total_score) >= 10 THEN true
    WHEN s.instrument_type = 'WHO5' AND (s.total_score - LAG(s.total_score) OVER (...)) >= 10 THEN true
    ELSE false
  END AS clinically_meaningful_improvement
FROM assessment_scores s;

-- Refresh schedule via pg_cron
SELECT cron.schedule('refresh-score-trajectories', '*/15 * * * *',
  'REFRESH MATERIALIZED VIEW CONCURRENTLY score_trajectories');
```

**Refresh strategy**: `CONCURRENTLY` to avoid locking reads during refresh. Requires a unique index on `(pseudonymous_user_id, instrument_type, administered_at)`.

**Rationale**: Pure SQL computation avoids application-layer round-trips. pg_cron is already used in the MHG Cloud SQL instance (confirmed via MTB-405 workbench survey schema work).

**Alternatives considered**: Application-layer computation on each API call — rejected (no caching, high latency at scale); separate timeseries DB — rejected (unnecessary complexity for current scale).

---

## R-02 — Cloud Tasks vs Cloud Scheduler for Adaptive Assessment Intervals

**Decision**: Cloud Tasks with per-task scheduling.

**Rationale**: Assessment intervals are per-user and adaptive (14/28/35 days based on individual severity band). Cloud Scheduler supports only fixed cron expressions shared across all users. Cloud Tasks allows each assessment schedule record to queue a task with a specific delivery time, enabling per-user adaptive scheduling.

**Pattern**:
```typescript
// When a new assessment score is stored:
const nextDelay = getIntervalDays(severity_band); // 14 | 28 | 35
const deliverAt = Date.now() + nextDelay * 86400 * 1000;

await cloudTasksClient.createTask({
  parent: ASSESSMENT_QUEUE,
  task: {
    scheduleTime: { seconds: deliverAt / 1000 },
    httpRequest: {
      httpMethod: 'POST',
      url: `${INTERNAL_API}/assessments/trigger`,
      body: Buffer.from(JSON.stringify({ pseudonymous_user_id, instrument_type })),
    },
  },
});
```

**Existing infrastructure**: Cloud Tasks is already enabled in the `mental-help-global-25` GCP project. A new queue (`assessment-scheduler`) needs to be created — scripted in chat-infra.

**Alternatives considered**: `pg_cron` polling table — rejected (polling not event-driven; does not support per-user adaptive intervals cleanly); Cloud Scheduler — rejected (fixed cron only, no per-user delivery time).

---

## R-03 — PostgreSQL Trigger-Enforced Append-Only Tables

**Decision**: Database-level `BEFORE UPDATE OR DELETE` trigger on `assessment_sessions`, `assessment_items`, `assessment_scores`.

**Implementation**:
```sql
CREATE OR REPLACE FUNCTION enforce_append_only()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Table % is append-only. Modifications are only permitted via the GDPR erasure cascade.',
      TG_TABLE_NAME;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assessment_sessions_append_only
  BEFORE UPDATE OR DELETE ON assessment_sessions
  FOR EACH ROW EXECUTE FUNCTION enforce_append_only();
-- Repeat for assessment_items, assessment_scores
```

**GDPR erasure exception**: The erasure cascade runs as the `erasure_service` database user, which has a separate role granted `TRIGGER DISABLE` on these tables for the duration of the erasure transaction only.

**Rationale**: Application-level guards can be bypassed by direct DB access, hotfixes, or script errors. DB-level trigger enforces the constraint regardless of the access path.

**Alternatives considered**: Row-level security with a special erasure role — rejected (more complex to maintain than a simple trigger); application-level guard only — rejected (insufficient for audit/compliance purposes).

---

## R-04 — F-beta Metric with β=4.47 (20:1 FN:FP Cost Asymmetry)

**Decision**: Implement F-beta using the standard formula with β=4.47.

**Formula**:
```
F_β = (1 + β²) × (precision × recall) / (β² × precision + recall)
```

For β=4.47 (reflecting that a false negative is ~20× more costly than a false positive in clinical safety contexts: β² ≈ 20):
```typescript
function fBeta(precision: number, recall: number, beta = 4.47): number {
  const b2 = beta * beta;
  return ((1 + b2) * precision * recall) / (b2 * precision + recall);
}
```

**Rationale for β=4.47**: β² = 19.98 ≈ 20, meaning recall (sensitivity) is weighted 20× more than precision. In a safety-critical context where missing a high-risk flag (false negative) is far more dangerous than an unnecessary review (false positive), this asymmetry is appropriate. The specific value is referenced in the PRD and should be configurable by the Clinical Lead post-deployment.

**Alternatives considered**: Standard F1 (β=1) — rejected (treats FN and FP equally, inappropriate for clinical safety); AUROC only — rejected (insufficient for threshold-based deployment decisions).

---

## R-05 — Bootstrap Confidence Interval for Cohen's Kappa

**Decision**: 1,000-iteration stratified bootstrap resampling on annotation pairs.

**Algorithm**:
```typescript
function bootstrapKappaCI(
  annotations: AnnotationPair[],
  iterations = 1000
): { lower: number; upper: number; mean: number } {
  const kappas = Array.from({ length: iterations }, () => {
    const sample = sampleWithReplacement(annotations, annotations.length);
    return computeCohenKappa(sample);
  });
  kappas.sort((a, b) => a - b);
  return {
    lower: kappas[Math.floor(iterations * 0.025)],
    upper: kappas[Math.ceil(iterations * 0.975)],
    mean: kappas[Math.floor(iterations * 0.5)],
  };
}
```

**Weighted kappa variants**:
- Linear weights: `w_ij = 1 - |i - j| / (k - 1)` for k categories
- Quadratic weights: `w_ij = 1 - (i - j)² / (k - 1)²`

**Fleiss' kappa** (for ≥3 raters): Standard multi-rater extension; computed separately.

**Rationale**: Bootstrap CI is the standard approach for kappa when the normality assumption may not hold (small N, skewed distributions). 1,000 iterations provides sufficient stability for the reported CI without excessive compute time.

**Alternatives considered**: Analytical asymptotic CI — rejected (requires normal distribution assumption; unreliable for small annotation batches); permutation test — rejected (more compute-intensive with no material benefit for this use case).

---

## R-06 — GCP Cloud SQL Separate Instance for Identity Map

**Decision**: New Cloud SQL instance (`chat-identity-map-dev` / `chat-identity-map-prod`) with distinct service account and VPC firewall rules.

**Provisioning script** (chat-infra):
```bash
# Create the identity map Cloud SQL instance
gcloud sql instances create chat-identity-map-dev \
  --project=mental-help-global-25 \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=europe-central2 \
  --network=default \
  --no-assign-ip \
  --availability-type=ZONAL

# Create a dedicated service account for auth service identity-map access only
gcloud iam service-accounts create auth-identity-map-sa \
  --project=mental-help-global-25 \
  --display-name="Auth Service — Identity Map DB Access"

# Grant only the auth service SA access to this instance
gcloud projects add-iam-policy-binding mental-help-global-25 \
  --member="serviceAccount:auth-identity-map-sa@mental-help-global-25.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# All other services explicitly denied (IAM deny policy)
gcloud iam policies create deny-identity-map-access \
  --project=mental-help-global-25 \
  ...
```

**Network isolation**: Private IP, same VPC as the main instance. No public IP. Auth service accesses via Cloud SQL Auth Proxy with the dedicated SA. All other services use the main instance SA which has no permissions on the identity map instance.

**Rationale**: Schema-level isolation (different schema, same instance) is insufficient — a superuser or misconfigured migration script could still access it. Instance-level isolation with distinct SA is the GDPR-compliant architecture.

---

## R-07 — Server-Side Post-Generation Response Filter (TypeScript/Express)

**Decision**: Synchronous middleware applied to all AI response payloads before delivery. Uses compiled RegExp patterns + a curated keyword set.

**Filter architecture**:
```typescript
// Prohibited patterns — compiled at startup for performance
const PROHIBITED_PATTERNS = [
  // Numeric scores near instrument names
  /\b(PHQ-?9|GAD-?7|PCL-?5|WHO-?5)\s*[:=\s]\s*\d{1,2}\b/gi,
  /\bscore[d]?\s+(of\s+)?\d{1,2}(\s+out\s+of\s+\d+)?\b/gi,
  // Diagnostic terminology
  /\b(major\s+depressive\s+disorder|clinical\s+depression|PTSD|post-?traumatic)\b/gi,
  /\b(diagnosis|diagnosed\s+with|you\s+have|you\s+suffer\s+from)\b/gi,
  // Clinical urgency language
  /\b(call\s+emergency|immediate\s+hospitali[sz]ation|crisis\s+intervention)\b/gi,
];

const PROHIBITED_KEYWORDS = new Set([
  'DSM-5', 'ICD-11', 'clinically significant', 'meets criteria',
  // ... curated list, not hardcoded instrument names
]);

export function postGenerationFilter(response: string): FilterResult {
  for (const pattern of PROHIBITED_PATTERNS) {
    if (pattern.test(response)) {
      return { blocked: true, reason: 'prohibited_pattern', original: response };
    }
  }
  for (const keyword of PROHIBITED_KEYWORDS) {
    if (response.toLowerCase().includes(keyword.toLowerCase())) {
      return { blocked: true, reason: 'prohibited_keyword', original: response };
    }
  }
  return { blocked: false };
}
```

**Fallback message**: Stored in the `sla_config`-adjacent configuration table (not hardcoded). Requires therapy team sign-off on content — schema and infrastructure are in scope; the approved fallback strings are therapy-gated.

**Performance**: Regex compilation at startup, not per-request. Expected p99 < 5ms for the filter itself on typical message lengths.

**Rationale**: Client-side filtering is bypassable via direct API calls. Async post-delivery logging is insufficient for safety (message already sent). Synchronous server-side filter is the only compliant architecture.

---

## R-08 — FHIR-Compatible Schema Design for PostgreSQL

**Decision**: Design assessment tables with FHIR-mappable column semantics but do NOT implement a FHIR server. Schema allows future FHIR R4 export as a separate phase.

**LOINC code assignments**:
| Instrument | FHIR Resource | LOINC Code |
|------------|---------------|------------|
| PHQ-9 | Observation | 44249-1 |
| GAD-7 | Observation | 69737-5 |
| PCL-5 | Observation | 91703-5 |
| WHO-5 | Observation | Local: `WHO5-TOTAL` |

**Schema column mapping**:
- `assessment_items` → FHIR QuestionnaireResponse.item[] — `item_key` maps to `QuestionnaireResponse.item.linkId`
- `assessment_scores` → FHIR Observation — `total_score` maps to `Observation.valueInteger`, `instrument_version` maps to `Observation.method`
- `scoring_key_hash` — SHA-256 of the instrument version's scoring key JSON; enables audit of score provenance

**Rationale**: FHIR server is a significant separate effort. Schema-compatible design costs nothing now and avoids a costly migration later.

---

## R-09 — k-Anonymity Suppression Pattern for SQL Analytics

**Decision**: `HAVING COUNT(DISTINCT pseudonymous_user_id) >= 10` guard on all cohort aggregate queries, implemented as a shared query helper.

**Implementation pattern**:
```typescript
// Shared helper — injected into all cohort analytics queries
function withKAnonymityGuard(query: Knex.QueryBuilder, k = 10): Knex.QueryBuilder {
  return query.having(
    knex.raw('COUNT(DISTINCT pseudonymous_user_id)'),
    '>=',
    k
  );
}
```

**Enforcement**: Linted rule in chat-backend to flag any analytics query builder call that doesn't use `withKAnonymityGuard`. This makes the guard a code-review-visible pattern, not just a runtime check.

**Rationale**: A HAVING clause on all aggregate queries is the standard SQL implementation of k-anonymity. Applying it as a shared helper function ensures consistency across all analytics query paths and makes it visible in code review.

---

## R-10 — QR Code Generation at 300 DPI (Node.js)

**Decision**: `qrcode` npm package (MIT license, widely used, no external service dependency).

**Usage**:
```typescript
import QRCode from 'qrcode';

const qrDataUrl = await QRCode.toDataURL(inviteUrl, {
  errorCorrectionLevel: 'H',  // Highest error correction for print use
  scale: 10,                   // ~300 DPI equivalent at standard print sizes
  margin: 4,
});
// Returns base64 PNG data URL; convert to Buffer for storage/download
```

**Print resolution**: At `scale: 10`, each QR module is 10px. A standard 25-module QR code for an 8-character code = ~250px × 250px at 25 DPI equivalent. For 300 DPI at A5 poster size, `scale: 50` is recommended (tested to produce ≥300 DPI at 5×5cm print dimensions).

**Alternatives considered**: Google Charts QR API — rejected (external service dependency, privacy concern for invite URL data); `qr-image` — rejected (less maintained than `qrcode`).

---

## Summary of All Decisions

| Research Item | Decision | Impact |
|---------------|----------|--------|
| R-01: RCI computation | PostgreSQL materialised view + pg_cron | No app-layer round-trips; consistent with existing DB stack |
| R-02: Assessment scheduler | Cloud Tasks (per-task delay) | Enables adaptive per-user intervals |
| R-03: Append-only enforcement | PostgreSQL BEFORE trigger | DB-level guarantee; survives code changes |
| R-04: F-beta β=4.47 | Standard formula, β configured | β² ≈ 20 reflects 20:1 FN:FP cost ratio |
| R-05: Bootstrap CI for kappa | 1,000-iteration resampling | Standard; no normality assumption required |
| R-06: Identity map isolation | Separate Cloud SQL instance + distinct SA | Strongest isolation; GDPR-compliant architecture |
| R-07: AI response filter | Synchronous server-side regex + keyword filter | Only compliant option; client-side bypassable |
| R-08: FHIR compatibility | Schema-compatible columns, not FHIR server | Future-proofs without current complexity |
| R-09: k-anonymity guard | HAVING COUNT DISTINCT >= 10 as shared helper | Data-layer enforcement; code-review visible |
| R-10: QR code generation | `qrcode` npm (MIT, no external service) | Self-contained; 300 DPI achievable with scale parameter |
