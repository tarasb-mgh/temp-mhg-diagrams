# Data Model: CX Agent Clinical Playbooks

**Feature**: 052-cx-clinical-playbooks
**Date**: 2026-04-15

## Entities

### 1. Session Parameters (Dialogflow CX — runtime only, not persisted)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| active_playbook | string | "general" | Currently active playbook: general, depression, anxiety, crisis |
| severity_level | string | "none" | Assessed severity: none, mild, moderate, severe |
| yes_count | integer | 0 | Count of affirmatively answered screening items |
| critical_flags | string | "none" | Safety-critical markers: none, self_harm, acute_panic |
| questions_covered | string | "" | Comma-separated screening item IDs (e.g., "D01,D02,D05") |
| co_occurring_signals | string | "none" | Detected signals for the non-active domain: none, depression, anxiety |

### 2. Assessment Schema Extensions (PostgreSQL — persisted)

#### assessment_scores.instrument_type (extended CHECK constraint)

Existing values: PHQ9, GAD7, PCL5, WHO5
New values: **CX_DEP**, **CX_ANX**

#### instrument_params (new rows)

| instrument_type | sd | reliability | cmi_threshold | notes |
|-----------------|-----|-------------|---------------|-------|
| CX_DEP | 4.0 | 0.85 | 3 | Provisional — calibrate after 100+ assessments |
| CX_ANX | 4.0 | 0.85 | 3 | Provisional — calibrate after 100+ assessments |

#### risk_thresholds (new rows)

| instrument_type | threshold_type | threshold_value | tier |
|-----------------|----------------|-----------------|------|
| CX_DEP | absolute | {"score": 11} | urgent |
| CX_DEP | item_response | {"item_key": "D18", "min_value": 1} | critical |
| CX_ANX | absolute | {"score": 11} | urgent |
| CX_ANX | item_response | {"item_key": "A05", "min_value": 1} | routine |

### 3. Assessment Records (existing tables, new data)

#### assessment_sessions (no schema change)

| Field | Value for CX screenings |
|-------|------------------------|
| pseudonymous_user_id | From authenticated user |
| instrument_id | UUID for CX_DEP or CX_ANX instrument definition |
| session_id | Dialogflow CX session mapped to chat session |
| status | "completed" or "abandoned" |

#### assessment_items (no schema change)

| Field | Value for CX screenings |
|-------|------------------------|
| item_key | D01-D20 (depression) or A01-A19 (anxiety) |
| response_value | 0 (no) or 1 (yes) |
| item_index | Sequential 0-based index within screening |

#### assessment_scores (extended CHECK only)

| Field | Value for CX screenings |
|-------|------------------------|
| instrument_type | CX_DEP or CX_ANX |
| total_score | Count of affirmative items (D01-D18 max 18, A01-A16 max 16) |
| severity_band | minimal, mild, moderate, severe |
| instrument_version | "1.0.0" |
| scoring_key_hash | SHA256 of scoring rubric JSON |

### 4. Analytics Events (existing table, new event data)

#### analytics_events (no schema change)

| Field | Value for CX screenings |
|-------|------------------------|
| event_type | "assessment_completed" or "assessment_abandoned" |
| pseudonymous_user_id | From authenticated user |
| cohort_id | From user's cohort membership (nullable) |
| metadata | See below |

**metadata shape**:
```json
{
  "instrument_type": "CX_DEP",
  "severity_band": "moderate",
  "total_score": 8,
  "max_score": 18,
  "critical_flags": "none",
  "screening_source": "cx_agent",
  "questions_covered_count": 14,
  "session_duration_seconds": 1200,
  "co_occurring_screening": "CX_ANX"
}
```

### 5. Agent Memory State Timeline Entry (GCS — persisted)

**Format**:
```json
{
  "role": "system",
  "content": "MEMORY: State timeline:\n- 2026-04-15T14:30:00Z: depression screening — moderate (yes_count: 8/18, critical_flags: none, questions: D01,D02,D04,D05,D07,D08,D11,D14,D16,D17). Key concerns: hopelessness, social withdrawal, sleep disruption. Professional help mentioned.",
  "meta": {
    "kind": "state_timeline",
    "updatedAt": "2026-04-15T14:30:00Z",
    "sourceSessionId": "session-uuid",
    "aggregatedBy": "webhook"
  }
}
```

### 6. Screening Item Banks (Dialogflow CX playbook instructions — not DB)

#### Depression Screening Items (D01-D20)

| ID | Domain | Scored | Critical |
|----|--------|--------|----------|
| D01 | Mood | Yes | No |
| D02 | Anhedonia | Yes | No |
| D03 | Emotional numbness | Yes | No |
| D04 | Hopelessness | Yes | No |
| D05 | Worthlessness/guilt | Yes | No |
| D06 | Pessimism | Yes | No |
| D07 | Energy/fatigue | Yes | No |
| D08 | Task initiation | Yes | No |
| D09 | Concentration | Yes | No |
| D10 | Cognitive slowing | Yes | No |
| D11 | Sleep changes | Yes | No |
| D12 | Appetite changes | Yes | No |
| D13 | Psychomotor changes | Yes | No |
| D14 | Social withdrawal | Yes | No |
| D15 | Daily overwhelm | Yes | No |
| D16 | Meaninglessness | Yes | **Yes** (auto-elevate to moderate) |
| D17 | Negative self-talk | Yes | **Yes** (auto-elevate to moderate) |
| D18 | Death ideation | Yes | **Yes** (auto-elevate to moderate; self-harm sub-q → severe) |
| D19 | Help-seeking | No | No |
| D20 | Coping attempts | No | No |

#### Anxiety Screening Items (A01-A19)

| ID | Domain | Scored | Critical |
|----|--------|--------|----------|
| A01 | Worry | Yes | No |
| A02 | Dread | Yes | No |
| A03 | Control difficulty | Yes | No |
| A04 | Relaxation inability | Yes | No |
| A05 | Panic attacks | Yes | No |
| A06 | Respiratory symptoms | Yes | No |
| A07 | Muscular tension | Yes | No |
| A08 | Autonomic symptoms | Yes | No |
| A09 | Vestibular symptoms | Yes | No |
| A10 | GI symptoms | Yes | No |
| A11 | Cognitive symptoms | Yes | No |
| A12 | Irritability (stress) | Yes | No |
| A13 | Sensory irritability | Yes | No |
| A14 | Functional impact | Yes | No |
| A15 | Avoidance | Yes | No |
| A16 | Sleep disruption | Yes | No |
| A17 | Coping strategies | No | No |
| A18 | Social support | No | No |
| A19 | Professional help | No | No |

## Relationships

```
User Session
  └── Session Parameters (runtime)
        ├── active_playbook → selects Playbook
        ├── severity_level → drives communication protocol
        └── questions_covered → maps to Screening Items

Assessment Session (persisted)
  ├── assessment_items[] → individual screening responses
  ├── assessment_scores[] → severity calculation
  └── risk_flags[] → triggered by threshold evaluation

Agent Memory (GCS)
  └── State Timeline entries → cross-session continuity
```

## State Transitions

### active_playbook

```
general → depression    (DEPRESSION_SIGNALS intent or LLM handoff)
general → anxiety       (ANXIETY_SIGNALS intent or LLM handoff)
general → crisis        (SUICIDAL_IDEATION intent)
depression → crisis     (D18 self-harm confirmed)
anxiety → crisis        (acute panic unresolvable)
depression → anxiety    (co-occurrence handoff after primary completes)
anxiety → depression    (co-occurrence handoff after primary completes)
depression → general    (screening completes, no co-occurrence)
anxiety → general       (screening completes, no co-occurrence)
crisis → general        (crisis protocol completes)
```

### severity_level

```
none → mild       (yes_count reaches 4)
none → moderate   (yes_count reaches 7, OR critical item D16/D17/D18 affirmed)
none → severe     (yes_count reaches 11, OR D18 self-harm confirmed)
mild → moderate   (yes_count reaches 7, OR critical item affirmed)
mild → severe     (yes_count reaches 11, OR D18 self-harm confirmed)
moderate → severe (yes_count reaches 11, OR D18 self-harm confirmed)
```

Severity can only increase during a session, never decrease (screening is additive).
