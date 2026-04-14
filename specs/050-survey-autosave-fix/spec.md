# Feature Specification: Survey Schema Autosave Fix + Regression Coverage

**Feature Branch**: `050-survey-autosave-fix`  
**Created**: 2026-04-14  
**Status**: Draft  
**Input**: User complaint: "sometimes autosave stops working during survey schema creation"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Race Condition Fix: Edits During In-Flight Save (Priority: P1)

A researcher is editing a survey schema with 10+ questions on a slow connection. They change a question's text, autosave fires, and while the PATCH request is in-flight they change another question. Currently, the second edit is silently lost because `savingRef.current` blocks the retry, and `setHasUnsavedChanges(false)` runs when the first (stale) save completes.

**Why this priority**: Silent data loss. The user sees "Saved" but their latest changes were never sent to the server. This is the most likely root cause of the user complaint.

**Independent Test**: Edit a field, wait for autosave to start, edit another field during the save, verify the server has both changes.

**Acceptance Scenarios**:

1. **Given** a draft schema with questions, **When** the user edits title while a save is in-flight, **Then** the new title is saved after the in-flight save completes (queued retry).
2. **Given** a draft schema, **When** `doSave()` is blocked by `savingRef.current`, **Then** a pending-save flag is set and the save retries automatically after the in-flight save completes.
3. **Given** a draft schema, **When** a save completes but there are newer local changes, **Then** `hasUnsavedChanges` remains `true` and the status indicator does NOT show "Saved".

---

### User Story 2 - Silent Validation Gate Feedback (Priority: P1)

A researcher adds a new question (e.g., single_choice) and autosave silently skips because the question text is empty or options are missing. The save status indicator still shows the previous "Saved [time]" with no indication that autosave is blocked. The researcher might close the tab believing their work is saved.

**Why this priority**: Misleading UX. The "beforeunload" dialog fires (good), but the user gets no proactive indication that autosave is blocked while editing.

**Independent Test**: Add a question with empty text, wait 3+ seconds, verify the UI shows "Unsaved changes" or similar indicator instead of the stale "Saved" timestamp.

**Acceptance Scenarios**:

1. **Given** a draft schema with one completed question showing "Saved", **When** the user adds a new question with empty text, **Then** the save status changes to indicate unsaved changes (not "Saved").
2. **Given** a schema with an incomplete choice question (no options), **When** 2+ seconds pass after the last edit, **Then** the UI shows a validation-specific indicator (e.g., "Complete all questions to save").
3. **Given** a schema where autosave was blocked by validation, **When** the user fills in the missing text/options, **Then** autosave fires within 2 seconds and status returns to "Saved".

---

### User Story 3 - Sync Server-Assigned Question IDs After Autosave (Priority: P2)

After autosave, new questions (without a pre-existing UUID) receive server-generated IDs. Currently, the frontend does not update its local state with these IDs. On subsequent saves, the server generates new UUIDs for the same questions, creating unnecessary churn and potential instability for visibility condition references.

**Why this priority**: Root cause of the historical 422-fix cycle (5+ previous fixes for ID-related issues). Lower priority than P1 because the backend position-based remapping handles it, but fixing this eliminates the need for future ID remapping patches.

**Independent Test**: Create a schema, add a question, wait for autosave, make another edit, verify the second PATCH includes the server-assigned question ID (not a missing/new one).

**Acceptance Scenarios**:

1. **Given** a draft schema, **When** a new question is added and autosave succeeds, **Then** the local question state includes the server-assigned UUID.
2. **Given** a question with a server-assigned ID, **When** the user edits the question text and autosave fires, **Then** the PATCH request includes the same ID (no new UUID generated).
3. **Given** two questions where Q2 has a visibility condition referencing Q1, **When** autosave fires twice, **Then** the visibility condition questionId remains stable (same UUID across saves).

---

### User Story 4 - Regression Test Suite: Survey Schema Autosave Coverage (Priority: P1)

The regression suite (`regression-suite/07-survey-schemas.yaml`) lacks explicit autosave tests. Existing tests cover CRUD operations but don't verify debounce behavior, save status indicator states, validation gate behavior, or race conditions.

**Why this priority**: Without regression coverage, future changes could reintroduce the same bugs. The test suite is the safety net.

**Independent Test**: Run `module:07-survey-schemas` and verify all new autosave test cases pass.

**Acceptance Scenarios**:

1. **Given** the regression suite, **When** `module:07-survey-schemas` is run, **Then** autosave-specific tests (SS-010 through SS-017) execute and pass.
2. **Given** a new survey schema, **When** all 16 question types are added with configuration, **Then** autosave fires for each and the final server state matches the UI state.
3. **Given** the regression suite, **When** a save-blocked scenario occurs (empty question text), **Then** the test verifies the save status indicator does NOT show "Saved".

---

### Edge Cases

- What happens when the user adds 50+ questions and the PATCH payload is very large? (Slow save increases race condition window)
- What happens if the network disconnects mid-save and reconnects? (savingRef stuck? Or caught by apiRequest try-catch?)
- What happens when two users edit the same schema concurrently? (Conflict detection is separate — 30s polling)
- What happens when the user rapidly toggles a question type between single_choice and free_text? (Options appear/disappear, validation gate oscillates)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST queue pending saves when a save is already in-flight, and retry automatically after the in-flight save completes.
- **FR-002**: System MUST NOT set `hasUnsavedChanges = false` if local state has changed since the save request was initiated.
- **FR-003**: System MUST show a distinct save status when autosave is blocked by form validation (incomplete questions).
- **FR-004**: System MUST update local question state with server-assigned UUIDs after each successful autosave.
- **FR-005**: System MUST maintain stable visibility condition `questionId` references across consecutive autosaves.
- **FR-006**: Regression suite MUST include autosave-specific test cases covering: debounce timing, validation gate, save status indicator, and multi-question-type schemas.

### Key Entities

- **SaveStatus**: Extended from `'idle' | 'saving' | 'saved' | 'error'` to include `'validation_blocked'`
- **useDebouncedSave hook**: Core autosave logic — affected by US1, US2, US3
- **SurveySchemaEditorView**: Parent component — needs to accept ID sync callback from save hook
- **regression-suite/07-survey-schemas.yaml**: Test definitions — needs new SS-010+ test cases

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero data loss when making edits during in-flight saves (race condition eliminated)
- **SC-002**: Save status indicator accurately reflects current state at all times (no stale "Saved" when unsaved changes exist)
- **SC-003**: New question IDs stable across consecutive saves (server-assigned ID reused, not regenerated)
- **SC-004**: Regression suite includes 7+ new autosave test cases, all passing on dev environment
- **SC-005**: No increase in 422/500 error rate on `PATCH /api/workbench/survey-schemas/:id` after deployment
