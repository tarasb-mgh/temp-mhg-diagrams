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
5. **Check Safety Review tab is present** — look for "Safety Review" / "Перевірка безпеки" / "Проверка безопасности" label in tab bar
6. Click into any available session
7. `browser_snapshot` — confirm message list renders
8. Look for assistant messages with a collapsible "CX Debug" / intent panel
9. If a session has CX metadata: expand the panel, confirm intent + confidence + RAG used fields display
10. Capture `browser_console_messages` + `browser_network_requests`

**Pass criteria**:
- Workbench loads without 500 errors
- Safety Review tab visible in queue tab bar
- CxMetadataPanel renders for sessions that have intent data (no blank panel, no JS crash)
- No 4xx/5xx on review API endpoints

---

### Flow 4 — Workbench: Safety Review Tab Filter

**Purpose**: Verify the crisis_low_confidence queue filter works.

Steps:
1. In the Review Queue, click the "Safety Review" tab
2. `browser_wait_for` — session list refreshes
3. `browser_snapshot` — capture the session list
4. Capture `browser_network_requests` — confirm the API request includes `tab=crisis_low_confidence`
5. Check that the API returns 200 (even if the list is empty — empty is valid)

**Pass criteria**:
- Tab click triggers API call with `tab=crisis_low_confidence`
- API returns 200 (not 400/500)
- No JS console errors on tab switch

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
- `review.queue.tabs.safetyReview` (added in this feature)
- Any key in `src/locales/en.json` under `review.queue.tabs.*`

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
- [ ] Flow 4 (Safety Review tab) — tab present, API call correct
- [ ] Flow 5 (i18n keys) — no literal dotted key strings in UI
- [ ] Server logs — zero ERROR entries post-deploy
- [ ] All monitored API endpoints return expected status codes
