# Regression Suite Changelog

## 2026-03-27 — Initial Release

**124 test cases** across 16 modules created as the baseline regression suite for the MHG Workbench.

### Modules

| Module | Tests | Priority Breakdown |
|--------|-------|--------------------|
| 01-auth | 11 | 3 P0, 4 P1, 4 P2 |
| 02-navigation | 12 | 2 P0, 8 P1, 2 P2 |
| 03-review-queue | 14 | 3 P0, 4 P1, 7 P2 |
| 04-review-session | 10 | 4 P0, 4 P1, 2 P2 |
| 05-review-dashboards | 6 | 0 P0, 3 P1, 3 P2 |
| 06-safety-flags | 6 | 0 P0, 6 P1, 0 P2 |
| 07-survey-schemas | 9 | 1 P0, 5 P1, 3 P2 |
| 08-survey-instances | 7 | 1 P0, 4 P1, 2 P2 |
| 09-user-management | 8 | 1 P0, 4 P1, 3 P2 |
| 10-group-management | 8 | 1 P0, 5 P1, 2 P2 |
| 11-privacy-gdpr | 4 | 0 P0, 2 P1, 1 P2, 1 P3 |
| 12-security-admin | 7 | 0 P0, 5 P1, 2 P2 |
| 13-settings | 3 | 0 P0, 2 P1, 1 P2 |
| 14-i18n | 6 | 3 P0, 2 P1, 0 P2, 1 P3 |
| 15-responsive | 7 | 0 P0, 3 P1, 4 P2 |
| 16-cross-cutting | 6 | 2 P0, 1 P1, 1 P2, 2 P3 |

### Known Issues Documented

- KI-001: `gradeDescription.buttonAriaLabel` literal i18n key in review session
- KI-002: Security section sidebar labels English-only in UK/RU locales
