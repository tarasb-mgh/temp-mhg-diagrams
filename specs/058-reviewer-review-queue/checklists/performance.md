# Performance Requirements Quality Checklist: Reviewer Review Queue

**Purpose**: Unit-test the performance requirements written in `spec.md` for completeness, clarity, consistency, measurability, and coverage. NOT load-testing — a quality gate on the requirements themselves before `/speckit.plan`.
**Created**: 2026-04-16
**Feature**: [spec.md](../spec.md)
**Audience**: PR reviewer + performance/SRE reviewer (release-gate depth)

## Coverage of Critical Surfaces

- [ ] CHK001 Are performance budgets defined for every critical Reviewer surface (queue list page, session-detail page, Reports page, notification bell list, locale switcher, Space dropdown)? [Coverage, Spec §SC-012, §SC-013o]
- [ ] CHK002 Are performance budgets defined for every critical interaction (autosave round-trip, focus-fetch reconciliation, Submit, change-request send, notification dismiss)? [Coverage, Spec §SC-013o]
- [ ] CHK003 Are performance requirements stated for cold start (first sign-in of the day) vs warm reload? [Gap]
- [ ] CHK004 Are performance requirements specified for the offline-mode replay phase (queue drain time, banner clear latency)? [Coverage, Spec §SC-008]
- [ ] CHK005 Are performance requirements stated for tag selector population at scale (50+ tags in Tag Center)? [Gap]
- [ ] CHK006 Are performance requirements stated for the language-filter live count refresh (FR-009c) under high session volume? [Gap, Spec §FR-009c]

## Measurability

- [ ] CHK007 Are TTI thresholds quantified per device tier (≤ 1.5 s desktop / ≤ 3.0 s tablet) with an explicit measurement methodology (Lighthouse, Playwright trace)? [Measurability, Spec §SC-012, §SC-013o]
- [ ] CHK008 Is "P95" used consistently for percentile-based budgets (autosave, focus-fetch) vs absolute values (TTI, FPS)? [Consistency, Spec §SC-013o]
- [ ] CHK009 Are Core Web Vitals targets (LCP ≤ 2.5 s, CLS ≤ 0.1, FID ≤ 100 ms) defined for ALL Reviewer surfaces or only the queue page? [Clarity, Coverage, Spec §SC-013o]
- [ ] CHK010 Is the "60 FPS sustained scroll" target measurable under specific conditions (transcript length, device profile)? [Clarity, Spec §SC-013o]
- [ ] CHK011 Is the bundle-size budget (≤ 350 KB gzipped) scoped precisely (route-only chunk vs entire shell)? [Clarity, Spec §SC-013o]

## Scalability & Load

- [ ] CHK012 Are performance requirements stated for the Pending tab at maximum expected size (250+, 1000+, 5000+ sessions)? [Coverage, Spec §SC-012]
- [ ] CHK013 Are concurrency assumptions documented (how many Reviewers from the same Space simultaneously rate the same session)? [Gap]
- [ ] CHK014 Is the 60-second background polling load profile (X / Y counter refresh) stated as an acceptable backend load? [Gap, Spec §FR-008a]
- [ ] CHK015 Are server-side budgets implied by client-side P95 numbers (autosave 500 ms, focus-fetch 800 ms) explicitly stated as backend SLA targets? [Consistency, Spec §SC-013o]
- [ ] CHK016 Are degradation requirements defined for high-load scenarios (graceful slowdown vs hard fail)? [Edge Case, Gap]

## Network & Reliability

- [ ] CHK017 Are performance requirements specified for slow-network conditions (3G profile)? [Gap]
- [ ] CHK018 Are autosave-success-rate thresholds defined (e.g., "≥ 99.5% of saves succeed within 3 retries")? [Gap, Spec §FR-031a]
- [ ] CHK019 Is offline-queue depth bounded (max entries before user prompted to re-establish connection)? [Gap, Spec §FR-031b]
- [ ] CHK020 Are performance requirements specified for the ping endpoint itself (poll frequency, latency, payload size)? [Gap, Spec §FR-031a]

## Resource & Cost Constraints

- [ ] CHK021 Are memory budgets defined for the Reviewer client (peak heap during long sessions, IndexedDB storage cap)? [Gap]
- [ ] CHK022 Are cost-of-polling considerations stated (X / Y refresh + ping + autosave heartbeat) for backend infrastructure planning? [Gap]
- [ ] CHK023 Is service-worker cache size budget defined for the PWA shell? [Gap, Spec §FR-046g]

## Edge Cases

- [ ] CHK024 Are performance requirements defined for a session with the maximum supported message count (e.g., 200+ messages)? [Edge Case, Gap]
- [ ] CHK025 Are performance requirements defined for the multi-tab focus-fetch under simultaneous focus on multiple tabs? [Edge Case, Spec §FR-034a]
- [ ] CHK026 Is the chat transcript scroll FPS target (≥ 60 FPS) measurable on the tablet tier specifically (not only desktop)? [Coverage, Spec §SC-013o]
- [ ] CHK027 Are performance requirements specified for the empty-state and skeleton paint-time (≤ 200 ms per FR-046b)? [Consistency, Spec §FR-046b]

## CI Enforcement

- [ ] CHK028 Is there a clear requirement that performance budget regressions fail CI for the feature branch? [Consistency, Spec §SC-013o]
- [ ] CHK029 Is the measurement environment specified (dev tier hardware definitions for desktop and tablet)? [Clarity, Spec §SC-013o, §Clarifications Round 5]
- [ ] CHK030 Are statistical-significance rules defined for performance regression alerts (single-run vs N-run aggregation)? [Gap]

## Notes

- 30 items.
- Tie any FAIL items back to specific FR / SC numbers; resolve before merge.
