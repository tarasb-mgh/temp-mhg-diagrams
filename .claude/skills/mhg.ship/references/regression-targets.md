# MHG UI Regression Targets

Full test flow list and error-hunting patterns for the Phase 4 regression sweep.
Run flows in order. After each flow, capture console + network state.

---

## Dev Environment Entry Points

| App | URL | Auth method |
|---|---|---|
| Chat (end-user) | `https://dev.mentalhelp.chat` | OTP (code in browser console) |
| Workbench | `https://workbench.dev.mentalhelp.chat` | OTP (code in browser console) |

---

## Test Flows

### Flow 1 — Chat: Auth + Message Send

**Purpose**: Verify chat frontend loads, auth works, agent responds.

Steps:
1. `browser_navigate` → `https://dev.mentalhelp.chat`
2. `browser_snapshot` — confirm login form visible
3. Enter email via `browser_fill_form`; submit
4. Open console (`browser_console_messages`) — find OTP code logged there
5. Enter OTP; submit
6. `browser_wait_for` — chat interface loads
7. `browser_snapshot` — confirm message input visible
8. Type a benign test message ("Привіт, як справи?") via `browser_fill_form`
9. Submit; `browser_wait_for` — assistant response appears
10. `browser_snapshot` — verify response rendered, no broken layout
11. Capture `browser_console_messages` — check for errors
12. Capture `browser_network_requests` — check for 4xx/5xx

**Pass criteria**:
- Login succeeds, OTP flow completes
- Message sends, assistant responds (non-empty text)
- No console errors
- No 4xx/5xx on `/api/chat/` endpoints

---

### Flow 2 — Chat: Feedback Button

**Purpose**: Verify the 1–5 star feedback button renders on assistant messages.

Steps (continue from Flow 1, already logged in):
1. Locate the assistant message bubble in the DOM via `browser_snapshot`
2. Check accessibility tree for a feedback/rating element on the assistant message
3. Click the rating (e.g., 4 stars)
4. `browser_wait_for` — confirm modal or success indicator
5. Capture `browser_network_requests` — verify `POST /api/chat/messages/:id/feedback` returns 200

**Pass criteria**:
- Rating UI visible on assistant messages
- Submit returns 200

---

### Flow 3 — Workbench: Auth + Review Session

**Purpose**: Verify workbench loads, a review session opens, CX metadata panel renders.

Steps:
1. `browser_navigate` → `https://workbench.dev.mentalhelp.chat`
2. Auth via OTP (same pattern as Flow 1)
3. Navigate to Review Queue (sidebar or direct URL)
4. `browser_snapshot` — confirm queue tabs visible
5. Click into any available session
7. `browser_snapshot` — confirm message list renders
8. Look for assistant messages with a collapsible "CX Debug" / intent panel
9. If a session has CX metadata: expand the panel, confirm intent + confidence + RAG used fields display
10. Capture `browser_console_messages` + `browser_network_requests`

**Pass criteria**:
- Workbench loads without 500 errors
- CxMetadataPanel renders for sessions that have intent data (no blank panel, no JS crash)
- No 4xx/5xx on review API endpoints

---

### Flow 4 — Workbench: Priority-Flagged Session Queue

**Purpose**: Verify that elevated-priority sessions surface at the top of the main review queue with a visual priority indicator, and that the review form shows the mandatory "Safety flag resolution" step.

**Prerequisite**: At least one session with `safety_priority = 'elevated'` must exist in dev. Seed with:
```sql
UPDATE sessions SET safety_priority = 'elevated' WHERE id = '<any pending session id>';
```

Steps:
1. `browser_navigate` → `https://workbench.dev.mentalhelp.chat`
2. Auth via OTP; navigate to Review Queue
3. `browser_snapshot` — confirm "Pending" tab is active
4. Verify elevated session appears above any normal sessions (check ordering in accessibility tree)
5. Verify the amber "Elevated" badge renders on the elevated session card
6. Click into the elevated session
7. `browser_snapshot` — confirm "Safety Flag Resolution" fieldset is visible in the right panel
8. Attempt to click "Submit Review" without selecting a disposition
9. Verify submit is blocked and amber warning text renders (`review.safetyFlag.resolutionRequired`)
10. Select "Resolve — no further action needed" radio
11. Add a test note in the textarea
12. Click "Submit Review" — `browser_wait_for` success confirmation
13. Capture `browser_network_requests` — verify `POST /api/review/sessions/:id/reviews/:id/submit` returns 200
14. Navigate back to queue — verify session no longer appears with elevated badge
15. Switch language to Ukrainian and Russian; `browser_snapshot` — verify no literal key strings

**Pass criteria**:
- Elevated sessions appear above normal sessions in the queue
- Amber "Elevated" badge visible on elevated session cards in all 3 locales
- "Safety Flag Resolution" fieldset renders only for elevated sessions (verify on a normal session too)
- Submit blocked when no disposition selected; amber validation message visible
- Resolve submission returns 200; session leaves elevated tier
- No JS console errors on queue load or flag resolution submit
- No `review.safetyFlag.*` literal key strings visible in any locale

---

### Flow 5 — Translation Key Completeness Check

**Purpose**: Detect missing i18n keys (untranslated keys appear literally in the UI).

Pattern to search for in `browser_snapshot` output and visible text:
- Dot-notation strings like `review.queue.tabs.safetyReview` appearing as literal UI text
- Any key matching pattern `[a-z]+\.[a-z]+(\.[a-z]+)+` visible in rendered text

Steps:
1. After each flow above, search the accessibility tree output for literal key patterns
2. Switch workbench language if possible (check for language toggle)
3. `browser_snapshot` after language switch — check for untranslated keys in uk/ru locale

**Common newly-added keys to verify are translated**:
- Any key in `src/locales/en.json` under `review.queue.*` added by recent features
- `review.priorityBadge.elevated` / `review.safetyFlag.*` (when spec 032 ships)

---

## Error Signatures to Hunt

### Console Errors

Flag any console message matching these patterns:

| Pattern | Likely cause |
|---|---|
| `TypeError: Cannot read properties of undefined` | Null metadata in CxMetadataPanel |
| `Uncaught Error: ...` | JS crash in new component |
| `Failed to load resource: net::ERR_` | Network/CORS issue |
| `Warning: Each child in a list should have a unique "key"` | React key issue |
| Literal i18n key (dotted string, no spaces) | Missing translation |
| `[object Object]` rendered in UI | Missing `.toString()` / serialization error |

### Network Errors (from `browser_network_requests`)

Flag requests where:
- Status `>= 400`
- URL contains `/api/`
- Method is `GET` or `POST` (not preflight OPTIONS)

Key endpoints to monitor:
| Endpoint | Expected status |
|---|---|
| `GET /api/review/sessions` | 200 |
| `GET /api/review/sessions/:id` | 200 |
| `GET /api/review/queue/counts` | 200 |
| `POST /api/chat/messages` | 200 |
| `POST /api/chat/messages/:id/feedback` | 200 |
| `POST /api/auth/login` | 200 |
| `POST /api/auth/verify` | 200 |

### Server Log Error Patterns (Cloud Run)

After running flows, check:
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR AND timestamp>="<ISO timestamp of deploy>"' \
  --project=mental-help-global-25 \
  --limit=50
```

Flag any log entries containing:
- `ERROR` severity
- Stack traces
- `null` / `undefined` property access errors
- Database query errors
- Unhandled promise rejections

---

## Regression Sweep Completion Checklist

Mark each item before declaring Phase 4 complete:

- [ ] Flow 1 (Chat auth + message) — console clean, network clean
- [ ] Flow 2 (Feedback button) — renders, submits 200
- [ ] Flow 3 (Workbench session + CX metadata) — panel renders, no crash
- [ ] Flow 4 (Priority-flagged queue) — elevated badge visible, resolution step renders, submit with disposition returns 200
- [ ] Flow 5 (i18n keys) — no literal dotted key strings in UI
- [ ] Server logs — zero ERROR entries post-deploy
- [ ] All monitored API endpoints return expected status codes
