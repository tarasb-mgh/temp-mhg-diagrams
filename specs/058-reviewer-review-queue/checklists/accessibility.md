# Accessibility Requirements Quality Checklist: Reviewer Review Queue

**Purpose**: Unit-test the accessibility requirements written in `spec.md` for completeness, clarity, consistency, measurability, and coverage. NOT a verification that the implementation works — a quality gate on the requirements themselves before `/speckit.plan`.
**Created**: 2026-04-16
**Feature**: [spec.md](../spec.md)
**Audience**: PR reviewer + a11y reviewer (release-gate depth)
**Conformance target**: WCAG 2.1 Level AA (Spec §FR-047a)

## Requirement Completeness

- [ ] CHK001 Are accessibility requirements specified for every interactive control listed in `FR-047a` (sidebar, locale switcher, Space dropdown, queue tabs, chip filters, language filter, paginator, session cards, transcript, score selector, criterion selector, validated-answer field, tag selectors and chips, Red Flag modal, autosave/offline banners, bell-icon notification list, persistent banner, Submit button)? [Completeness, Spec §FR-047a]
- [ ] CHK002 Are keyboard-operability requirements stated for all newly-introduced custom controls (chip-bar multi-select, language-checkbox group, X / Y counter)? [Coverage, Gap, Spec §FR-047a]
- [ ] CHK003 Are focus-management requirements specified for modal flows (Red Flag modal, "Stay on page" confirm modal, change-request form)? [Gap, Spec §FR-026, §FR-033]
- [ ] CHK004 Are skip-link / landmark requirements specified for the page structure (header, sidebar, main, banner)? [Gap]
- [ ] CHK005 Are accessibility requirements stated for the empty / loading / error states (FR-046a..e), including illustration alt-text policy? [Coverage, Spec §FR-046a..e]
- [ ] CHK006 Are screen-reader announcement requirements (`aria-live`) specified for every dynamic surface (offline banner, notification banner, Submit countdown, error state, autosave indicators, X / Y counter updates)? [Completeness, Spec §FR-031b, §FR-039a, §FR-018a, §FR-046d, §FR-047a]
- [ ] CHK007 Are accessibility requirements specified for the per-message tag comment fields (relationship between tag chip and the comment field — `aria-describedby`, etc.)? [Gap]

## Requirement Clarity

- [ ] CHK008 Is "WCAG 2.1 Level AA" decomposed into measurable specifics in the spec, not just a label? [Clarity, Spec §FR-047a]
- [ ] CHK009 Are colour-contrast thresholds quantified (≥ 4.5:1 normal text, ≥ 3:1 large text, ≥ 3:1 non-text UI components)? [Clarity, Spec §FR-047a]
- [ ] CHK010 Is "visible focus indicator" specified with measurable properties (outline width, contrast against background)? [Clarity, Gap, Spec §FR-047a]
- [ ] CHK011 Are touch-target size requirements quantified for the tablet tier (≥ 44×44 px)? [Clarity, Spec §FR-046f]
- [ ] CHK012 Is "decorative illustration" criterion (`aria-hidden=true`) consistently applied to every illustration in empty/loading/error states? [Consistency, Spec §FR-046c, §FR-046d]

## Consistency Across States

- [ ] CHK013 Are aria-live politeness levels (polite vs assertive) used consistently across the spec (banner = polite, error state = assertive, others)? [Consistency, Spec §FR-031b, §FR-039a, §FR-046d, §FR-046e, §FR-047a]
- [ ] CHK014 Are tooltip-on-hover requirements (FR-024d) reconciled with the keyboard-only user need (tooltip must also appear on focus)? [Consistency, Spec §FR-024d]
- [ ] CHK015 Are `[Updated by another tab]` and tag conflict indicator surfaces accessibility-equivalent across visual and screen-reader modes? [Coverage, Spec §FR-034a]
- [ ] CHK016 Is the Submit countdown label (`⟳ Submit (N)`) accessible-name strategy unambiguous (does the spinner glyph have a textual equivalent for SR)? [Ambiguity, Spec §FR-018a]

## Coverage of Scenarios

- [ ] CHK017 Are accessibility requirements specified for the Reviewer working entirely via keyboard (no mouse) end-to-end through one full happy path? [Coverage, Gap]
- [ ] CHK018 Are accessibility requirements specified for screen-reader-only users navigating between Pending and Completed tabs and opening a session? [Coverage, Gap]
- [ ] CHK019 Are reduced-motion preferences (skeleton animation, spinner, autosave banner transition) specified to honour `prefers-reduced-motion`? [Gap, Spec §FR-046b]
- [ ] CHK020 Are accessibility requirements specified for the mobile read-only tier (FR-046f) — not just an absence of editor controls? [Gap, Spec §FR-046f]
- [ ] CHK021 Are PWA-installed fullscreen accessibility requirements (no chrome/back, but still navigable) addressed? [Gap, Spec §FR-046g]

## Measurability

- [ ] CHK022 Is the axe-core gating threshold ("0 critical, 0 serious") consistent everywhere it appears (FR-047b vs SC-013g)? [Consistency, Spec §FR-047b, §SC-013g]
- [ ] CHK023 Is "screen-reader announces transitions" measurable through a specific E2E assertion pattern? [Measurability, Spec §FR-046e, §SC-013g]
- [ ] CHK024 Are Lighthouse a11y targets quantified (e.g., "≥ 90 a11y category score") or only the binary axe gate? [Gap, Spec §FR-047b]

## Localization × Accessibility

- [ ] CHK025 Are locale-switching expectations (FR-002a) accessibility-correct (`html[lang]` attribute updates, `dir` changes if RTL added later)? [Coverage, Gap, Spec §FR-002a]
- [ ] CHK026 Is the rule "tag selector follows chat language while UI follows user locale" reconciled with `html[lang]` semantics for screen readers? [Consistency, Spec §FR-021a, §FR-024c, §FR-002a]

## Error & Edge Cases

- [ ] CHK027 Are accessibility requirements specified for the "browser not supported" full-page notice (FR-046i) — keyboard-reachable, semantic landmarks, language? [Coverage, Spec §FR-046i]
- [ ] CHK028 Are accessibility requirements specified for the multi-tab focus-fetch gating overlay (FR-034a) — focus trap, escape behaviour, screen-reader announcement? [Coverage, Gap, Spec §FR-034a]
- [ ] CHK029 Is the "(deleted)" tag chip rendering accessible (does the screen reader convey the deleted state separately from the tag name)? [Coverage, Gap, Spec §FR-021b, §EC-16]

## Notes

- 29 items.
- Conformance target: WCAG 2.1 AA. Mark off resolved items during spec review.
