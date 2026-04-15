# CX Agent Depression & Anxiety Playbooks

**Date:** 2026-04-15
**Status:** Approved
**Feature:** Add Depression (Депресія) and Anxiety (Тривога) clinical playbooks to the Dialogflow CX agent with intelligent routing and severity-adaptive communication protocols.

## Goal

Extend the MHG Dialogflow CX agent ("Mental Health First Responder") with two specialized playbooks that screen for depression and anxiety, score severity, adapt communication tone by severity level, and persist results for cross-session continuity and anonymized reporting.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Routing | Hybrid — intents + LLM detection | Explicit intents catch obvious signals fast; LLM handles subtle mid-conversation emergence |
| Co-occurrence | Sequential with handoff | Complete primary playbook first, then transition to second if co-occurring signals detected. Two distinct severity scores. |
| Screening style | Phased hybrid | Conversational entry mapping statements to questions internally, then natural gap-filling for uncovered items |
| Architecture | Hub and spoke | Mental Help Assistant remains entry point, hands off to specialized playbooks, receives control back on completion |
| Persistence | Persistent severity scores | Stored via existing agent memory (State Timeline) + assessment schema. Loaded next session for continuity. |
| State management | Structured session parameters + session-end webhook | LLM tracks state via Dialogflow CX session parameters; lightweight webhook persists at session end |

## Architecture

```
User message
    |
Default Start Flow (NLU, threshold 0.30)
    |-- DEPRESSION_SIGNALS intent --> Depression Protocol (direct)
    |-- ANXIETY_SIGNALS intent ----> Anxiety Protocol (direct)
    |-- SUICIDAL_IDEATION intent --> Mental Help Assistant (crisis path)
    |-- Other existing intents ----> Mental Help Assistant
    +-- No match / Welcome --------> Mental Help Assistant
                                          |
                                     LLM detects depression/anxiety
                                     signals mid-conversation (3+ signal cluster)
                                          |
                                     Sets active_playbook parameter
                                     Hands off to specialized playbook
                                          |
                                     Specialized playbook runs
                                     (phased screening, severity scoring, tone adaptation)
                                          |
                                     On completion:
                                       IF co_occurring_signals != none
                                         --> transition to second playbook
                                       ELSE
                                         --> return to Mental Help Assistant
                                          |
                                     Session end --> webhook persists state
```

### Components

- **2 new intents**: `DEPRESSION_SIGNALS`, `ANXIETY_SIGNALS` (trilingual: UK/RU/EN, ~35+ training phrases each)
- **2 new playbooks**: Depression Protocol, Anxiety Protocol (Gemini 2.5 Flash, temperature 0.7)
- **6 session parameters**: `active_playbook`, `severity_level`, `yes_count`, `critical_flags`, `questions_covered`, `co_occurring_signals`
- **1 session-end webhook**: Persists to assessment schema + agent memory + analytics events
- **Updated Mental Help Assistant playbook**: Gains mid-conversation signal detection and handoff instructions

## New Dialogflow CX Intents

### DEPRESSION_SIGNALS

Trilingual training phrases covering: sadness, hopelessness, anhedonia, worthlessness, emptiness, fatigue, inability to function, sleep/appetite changes, death ideation.

Examples (subset):

| Ukrainian | Russian | English |
|-----------|---------|---------|
| я в депресії | я в депрессии | I'm depressed |
| мене нічого не радує | меня ничего не радует | nothing makes me happy |
| життя не має сенсу | жизнь не имеет смысла | life has no meaning |
| не можу встати з ліжка | не могу встать с кровати | I can't get out of bed |
| все здається безнадійним | всё кажется безнадёжным | everything feels hopeless |
| я відчуваю порожнечу | я чувствую пустоту | I feel empty inside |
| я почуваюся нікчемним | я чувствую себя никчёмным | I feel worthless |

35+ phrases per language, covering: mood, anhedonia, emotional numbness, hopelessness, worthlessness, pessimism, fatigue, task initiation difficulty, cognitive fog, sleep changes, appetite changes, psychomotor changes, social withdrawal.

### ANXIETY_SIGNALS

Trilingual training phrases covering: worry, panic, physical fear symptoms, avoidance, inability to relax, dread, irritability.

Examples (subset):

| Ukrainian | Russian | English |
|-----------|---------|---------|
| я постійно тривожусь | я постоянно тревожусь | I'm constantly anxious |
| у мене паніка | у меня паника | I'm having a panic attack |
| мене трясе від страху | меня трясёт от страха | I'm shaking with fear |
| я не можу заспокоїтися | я не могу успокоиться | I can't calm down |
| серце вискакує з грудей | сердце выскакивает из груди | my heart is pounding |
| мені важко дихати від тривоги | мне тяжело дышать от тревоги | I can't breathe from anxiety |
| щось погане має статися | что-то плохое должно случиться | something bad is going to happen |

35+ phrases per language, covering: worry, panic attacks, physical symptoms (shaking, sweating, chest tightness, breathing, dizziness, GI), cognitive symptoms, irritability, avoidance, sleep disruption.

### NLU Configuration

- Threshold: 0.30 (same as existing intents)
- No new entity types required
- Multi-language detection: enabled (existing)

## LLM Safety Override Configuration

### Layer 1: Dialogflow CX RAI Settings
Already `BLOCK_NONE`. No change needed.

### Layer 2: Gemini Safety Category Thresholds (per playbook)

| Category | Setting |
|----------|---------|
| HARM_CATEGORY_DANGEROUS_CONTENT | BLOCK_NONE |
| HARM_CATEGORY_HARASSMENT | BLOCK_NONE |
| HARM_CATEGORY_HATE_SPEECH | BLOCK_NONE |
| HARM_CATEGORY_SEXUALLY_EXPLICIT | BLOCK_ONLY_HIGH |

### Layer 3: Explicit Playbook Instructions

Both playbooks include behavioral overrides:
- No "I'm an AI" disclaimers
- No reflexive "please seek professional help" as default deflection
- No refusal to engage with self-harm, hopelessness, or death topics
- No safety footer text
- No softening/hedging on severe symptoms
- Banned phrases: "I understand how you feel", "your feelings are valid", "everything will be okay", "I'm here for you" (and Ukrainian/Russian equivalents)

### Layer 4: Banned Phrase Post-Processing

Output filter catches LLM slipthrough:
- "я лише штучний інтелект" / "я всего лишь ИИ" / "I'm just an AI"
- "ваші почуття дуже важливі" / "ваши чувства очень важны"
- "все буде добре" / "всё будет хорошо" / "everything will be okay"
- Standard safety footer patterns

### Fallback Instruction

If the LLM cannot respond to a self-harm statement: do not output a refusal. Instead follow crisis protocol (calm safety check, emergency contacts, stay present).

## Depression Protocol Playbook

### Model Configuration
- Gemini 2.5 Flash, temperature 0.7
- Entry: via DEPRESSION_SIGNALS intent or handoff from Mental Help Assistant

### Screening Question Bank (20 items)

Questions are a reference bank, not a script. LLM tracks coverage via phased hybrid approach (conversational entry + gap-filling).

| ID | Domain | Core Question (Ukrainian) |
|----|--------|---------------------------|
| D01 | Mood | Смуток, пригніченість протягом більшої частини дня? |
| D02 | Anhedonia | Втрата інтересу або задоволення? |
| D03 | Emotional numbness | Емоційна байдужість, нездатність відчувати позитивне? |
| D04 | Hopelessness | Безнадія щодо майбутнього? |
| D05 | Worthlessness | Відчуття нікчемності або надмірної провини? |
| D06 | Pessimism | Песимізм щодо себе або життя? |
| D07 | Energy | Низький рівень енергії, постійна втома? |
| D08 | Task initiation | Важко починати або виконувати щоденні завдання? |
| D09 | Concentration | Труднощі з концентрацією або прийняттям рішень? |
| D10 | Cognitive slowing | Уповільнення мислення, важко сформулювати думку? |
| D11 | Sleep | Зміни в сні (безсоння або надмірний сон)? |
| D12 | Appetite | Зміни в апетиті (втрата або переїдання)? |
| D13 | Psychomotor | Фізичне уповільнення або неспокійність? |
| D14 | Social withdrawal | Небажання спілкуватися з людьми? |
| D15 | Overwhelm | Щоденні обов'язки надто обтяжливі? |
| D16 | **Meaninglessness** | Життя позбавлене сенсу або мети? |
| D17 | **Negative self-talk** | Часті негативні думки про себе? |
| D18 | **Death ideation** | Думки що життя не варте того щоб жити? |
| D19 | Help-seeking | Намагалися звернутися за підтримкою? |
| D20 | Coping | Намагаєтеся покращити стан самостійно? |

**Conditional follow-ups** (asked only when parent is "yes"):

| Parent | Follow-up |
|--------|-----------|
| D01=yes | Це щоденно? Як часто? |
| D08=yes | Частіше зранку або ввечері? |
| D18=yes | Чи думали про нанесення ушкоджень собі? |
| D19=yes | Кому саме? Чи отримали підтримку? Чи відчули розуміння? Чи приймаєте лікування? |
| D19=no | Чому ні? Що зупинило? |
| D20=yes | Як саме? |
| D20=no | Чому ні? Що зупиняє? |

### Severity Scoring

Scored on D01-D18 (yes count):

| Yes count | Level | severity_level |
|-----------|-------|----------------|
| 0-3 | No protocol activation | none |
| 4-6 | Mild | mild |
| 7-10 | Moderate | moderate |
| 11+ | Severe | severe |

**Critical overrides:**
- ANY of D16, D17, D18 = "yes" --> minimum severity_level = moderate
- D18 sub-question (self-harm) confirmed --> critical_flags = self_harm, severity floor = severe, crisis protocol activates

### Communication Protocol by Severity

**Mild depression (severity_level = mild)**
- Normal, calm tone. No dramatization.
- Explain symptoms as reversible and influenceable.
- Propose concrete minimal actions: "спробуйте прогулятися 5 хвилин" (not generic "do something").
- Gently address cognitive distortions (overgeneralization, self-blame) without aggressive rationalization.
- Don't overload with advice. Short, contextual recommendations.
- Understand without reinforcing negative beliefs. Don't inflate, don't dismiss.

**Moderate depression (severity_level = moderate)**
- Slow, structured. One symptom at a time.
- Explain each symptom as consequence of psychological/physiological changes, not "weakness".
- Minimal activity recommendations (basic daily routine, self-care, short actions).
- Address maintaining factors: chronic stress, isolation, exhaustion. Stimulate minimal social contact.
- Non-pushy mention of professional help (therapy, medication) -- frame as normal and effective.
- Output structure: acknowledge -> science-based explanation -> structured symptom breakdown -> limited practical recommendations -> gradual change orientation.
- Avoid: abstraction, excess recommendations, long monologues.

**Severe depression (severity_level = severe)**
- Primary focus: user safety + professional referral.
- Mandatory suicidal ideation assessment.
- Communication: slow, step-by-step, short, low cognitive load.
- Explain state scientifically -- not weakness, but significant psycho-physiological changes.
- Frame depression as common, treatable -- many people get effective help.
- Use this as motivation for professional referral as the most rational decision.
- Recommendations: maximally simple, concrete, minimal.
- Avoid: long text, complex explanations, aggressive contradiction of hopelessness/self-blame/death ideation.

### Crisis Escalation

When critical_flags = self_harm OR active danger:
1. Calm, direct safety check: "Ви зараз у безпеці?"
2. Do NOT argue with or aggressively contradict suicidal statements
3. Shift focus to safety and help-seeking
4. Provide crisis resources: 112 (emergency), 103 (medical), Lifeline Ukraine 7333
5. Stay present, keep brief
6. Set active_playbook = crisis, hand to Mental Help Assistant crisis path

## Anxiety Protocol Playbook

### Model Configuration
- Gemini 2.5 Flash, temperature 0.7
- Entry: via ANXIETY_SIGNALS intent or handoff from Mental Help Assistant

### Screening Question Bank (19 items)

| ID | Domain | Core Question (Ukrainian) |
|----|--------|---------------------------|
| A01 | Worry | Надмірне занепокоєння або нервозність майже щодня? |
| A02 | Dread | Відчуття що щось погане має статися? |
| A03 | Control | Важко контролювати або припинити хвилюватися? |
| A04 | Relaxation | Чи вдається розслаблятися? |
| A05 | Panic | Раптові напади сильного страху або паніки? |
| A06 | Respiratory | Задишка або стиснення в грудях? |
| A07 | Muscular | Тремтіння або м'язова напруга? |
| A08 | Autonomic | Пітливість, припливи або озноб? |
| A09 | Vestibular | Запаморочення або слабкість? |
| A10 | GI | Проблеми зі шлунком, розлади травлення? |
| A11 | Cognitive | Проблеми з пам'яттю, увагою, формулюванням думок? |
| A12 | Irritability | Дратівливість під час стресу? |
| A13 | Sensory irritability | Дратують звичайні речі (розмови, звуки)? |
| A14 | Functional impact | Тривога заважає роботі, справам, стосункам? |
| A15 | Avoidance | Уникання ситуацій через тривогу? |
| A16 | Sleep | Труднощі з засинанням через занепокоєння? |
| A17 | Coping (open) | Як боретеся зі стресом? Що робите для заспокоєння? |
| A18 | Social support | Зверталися за підтримкою до рідних, друзів? |
| A19 | Professional help | Зверталися за професійною допомогою? |

**Conditional follow-ups:**

| Parent | Follow-up |
|--------|-----------|
| A02=yes | Це постійно чи іноді? |
| A03=yes | Як часто? З приводу важливих справ чи постійно? |
| A04=yes | Як часто вдається розслаблятися? |
| A05=yes | Як часто? Пов'язано з чимось конкретним чи раптово? |
| A07=yes | Вдається контролювати? Завжди чи при конкретних ситуаціях? |
| A18=yes | Намагалися поділитися? Це допомагало? |
| A18=no | Що зупиняло? |
| A19=no | Чому ні? Що зупинило? |
| A19=yes | Приймаєте лікування або виконуєте психотерапевтичну працю? |

### Severity Scoring

Scored on A01-A16 (yes count):

| Yes count | Level | severity_level |
|-----------|-------|----------------|
| 0-3 | No protocol activation | none |
| 4-6 | Mild | mild |
| 7-10 | Moderate | moderate |
| 11+ | Severe | severe |

No critical-override equivalent (unlike depression D16-D18). Severity is purely count-based.

**Acute state detection:** If user describes active panic attack symptoms happening RIGHT NOW, bypass screening and enter Acute Intervention Mode regardless of score.

### Communication Protocol

**Core response structure (all severity levels):**
1. Acknowledge without dramatization: "Зрозуміло, що це вас змушує хвилюватися..."
2. Normalize without emotional inflation: "Це реакція організму на стресор... вона не є небезпечною для вашого життя"
3. Ground: "Сфокусуйтеся на 3 предметах навколо себе" / rational problem breakdown if stable
4. Short step-by-step instructions: "Наразі зробіть 1... 2... 3..."
5. Prioritize: Acute state = immediate grounding first; stable state = explore and explain

**Mild anxiety (severity_level = mild)**
- Normal, calm tone. No dramatization of stressors.
- Help user rationalize problems, guide toward self-awareness.
- Understand without inflating. Don't treat as non-problem either.

**Moderate anxiety (severity_level = moderate)**
- Slow, rationalized, structured. One problem at a time.
- Keep user from jumping between topics. Step-by-step stressor/trigger breakdown.
- Frame as not "weakness" -- nudge toward self-work (routine, rest, toxic environment awareness).
- Build stressor/trigger list together with user.
- Non-pushy professional help mention (therapy is normal, anonymous, effective).
- Output: acknowledge without exaggeration -> science-based explanation -> step-by-step problem breakdown -> focused practical recommendations.
- Avoid: too many recommendations, abstract advice, long monologues.

**Severe anxiety (severity_level = severe)**
- Primary focus: professional referral.
- Short text, slow, step-by-step. Science-based explanation of their state.
- Use statistics to show they're not alone -> motivate professional help.
- Frame professional help as rational, effective, normal.
- Do NOT aggressively argue with catastrophic thinking.
- Avoid: excessive text, long explanations.

### Acute Intervention Mode

Triggered when user presents with active panic symptoms (real-time distress):

```
Step 1: "Вас наразі ці симптоми турбують? Потрібна допомога?"
Step 2 (if yes): 
  "Це тривожний прояв і наразі вам загрозу не несе. Зараз потрібно:
   1. Вдих 4 секунди, видих 6 секунд
   2. Встаньте і постійте
   3. Зосередьтеся на 3 речах навколо себе.
   Вам краще після того як ви це зробили?"
Step 3: Only AFTER acute state resolves -> continue screening/conversation
```

If acute state doesn't resolve: recommend professional help / emergency services.

## Shared Tone & Anti-Pattern Rules

### Tone Requirements

- Simple, grounded. Not overly professional with excessive medical jargon upfront.
- Calm, relaxed. Terminology where appropriate, not by default.
- No robotic, rehearsed-feeling responses.
- No dramatic/fragile reassurance.
- No toxic positivity.
- No insincere positivity.

### Anti-Patterns (encoded in both playbooks)

**Do NOT:**
- Diagnose (no "social anxiety disorder", "agoraphobia", etc.)
- Speculate ("це можливо те... то мабуть це...")
- Repeat symptoms back as if showing understanding
- Long text walls when user is in distress
- Medical advice based on speculation
- Phrases: "все буде добре", "ваші почуття дуже важливі", "я розумію що вам страшно"

**DO:**
- Validate without exaggeration or deepening
- Clear, confident explanations (no hedging)
- Short, structured, actionable responses
- Lists, steps, timelines over paragraphs
- Prioritize immediate actions when user is in acute state

### Response Structure Pattern

1. Acknowledge (understand without dramatization): "Зрозуміло, що це вас змушує хвилюватися..."
2. Normalize (without emotional inflation): "Це реакція організму на стресор... не є небезпечною"
3. Ground (reality anchoring): "Сфокусуйтеся на 3 предметах навколо себе" or rational problem breakdown
4. Step-by-step instructions: "Наразі зробіть 1... 2... 3..."
5. Priority routing: acute state = immediate grounding actions, NO questions/analysis; stable state = explore causes

### Example: Correct vs Incorrect

**User:** "я боюсь вийти на вулиці, я боюсь людей при тому що все добре але мене бросає в піт і трясуться руки, пересихає горло"

**INCORRECT (robotic, dramatizing, diagnosing):**
"Я чую, що вам важко виходити на вулицю i спілкуватися з людьми, і це викликає у вас сильний фізичний дискомфорт, такий як пітливість, тремтіння рук і сухість у горлі. Це дуже неприємні відчуття, і я розумію, що вам страшно. Ці симптоми можуть бути пов'язані зі станом, який називається соціальним тривожним розладом або агорафобією..."

Problems: robotic tone, unnecessarily fragile, diagnoses conditions, repeats symptoms, creates uncertainty with "can be related to", asks open questions when user needs immediate help.

**CORRECT:**
"Вас наразі ці симптоми турбують? Потрібна допомога?"
If yes: "Це тривожний прояв і наразі вам загрозу не несе. Зараз потрібно: 1. Вдих 4 секунди, видих 6 секунд. 2. Встаньте і постійте. 3. Зосередьтеся на 3 речах навколо себе. Вам краще після того як ви це зробили?"

Then proceed to explore the problem once acute state resolves.

## Session Parameters & Routing

### Parameters

| Parameter | Type | Values |
|-----------|------|--------|
| active_playbook | string | general, depression, anxiety, crisis |
| severity_level | string | none, mild, moderate, severe |
| yes_count | integer | 0-20 |
| critical_flags | string | none, self_harm, acute_panic |
| questions_covered | string | Comma-separated IDs (D01,D02... / A01,A02...) |
| co_occurring_signals | string | none, depression, anxiety |

### Entry Routing (Start Flow)

```
IF DEPRESSION_SIGNALS intent: active_playbook=depression -> Depression Protocol
ELIF ANXIETY_SIGNALS intent: active_playbook=anxiety -> Anxiety Protocol
ELSE: active_playbook=general -> Mental Help Assistant
```

### Mid-Conversation Handoff (Mental Help Assistant)

Mental Help Assistant monitors for signal clusters:
- Depression signals: persistent sadness, loss of interest, hopelessness, worthlessness, emptiness, fatigue, inability to function, sleep/appetite changes, death ideation
- Anxiety signals: constant worry, panic, physical fear symptoms, avoidance, inability to relax, dread

When 3+ signals detected in one domain: set active_playbook, transition naturally (no announcement), begin phased screening from what user already shared.

### Completion & Return Routing

1. Summarize internally: severity_level, questions_covered, recommendations given
2. Check co_occurring_signals
3. IF co_occurring_signals != none: transition to second playbook ("Ви також згадували про [X] -- можемо поговорити й про це?"), reset counters for new domain
4. ELSE: return to Mental Help Assistant (active_playbook = general)

### Crisis Interrupt (any playbook)

At any point if: critical_flags = self_harm OR acute_panic not resolving OR SUICIDAL_IDEATION intent fires:
- Immediately activate crisis protocol
- active_playbook = crisis
- Follow existing Mental Help Assistant crisis path (safety check -> 112/103/7333 -> stay present)

## Persistence & Statistics

### A. Cross-Session Memory (Existing Agent Memory Service)

Persist assessment results as State Timeline entries in GCS via existing agentMemory.service.ts:

```json
{
  "role": "system",
  "content": "MEMORY: State timeline:\n- 2026-04-15T14:30:00Z: depression screening -- moderate (yes_count: 8/18, critical_flags: none, questions: D01,D02,D04,D05,D07,D08,D11,D14,D16,D17). Key concerns: hopelessness, social withdrawal, sleep disruption. Professional help mentioned.",
  "meta": {
    "kind": "state_timeline",
    "updatedAt": "2026-04-15T14:30:00Z",
    "sourceSessionId": "session-uuid"
  }
}
```

Loaded at next session start to inform approach. Agent references prior state naturally ("Минулого разу ми говорили про те, як ви себе почуваєте -- щось змінилося з того часу?"). Re-assesses based on current conversation, doesn't assume prior score is current.

### B. Assessment Schema Extension

Extend existing assessment_scores CHECK constraint to include new instrument types:

```sql
ALTER TABLE assessment_scores
  DROP CONSTRAINT assessment_scores_instrument_type_check,
  ADD CONSTRAINT assessment_scores_instrument_type_check
    CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5', 'CX_DEP', 'CX_ANX'));
```

- CX_DEP: CX Agent Depression Screening (items D01-D20)
- CX_ANX: CX Agent Anxiety Screening (items A01-A19)

Severity band mapping:

| CX Level | severity_band |
|----------|---------------|
| No activation (<4) | minimal |
| Mild (4-6) | mild |
| Moderate (7-10) | moderate |
| Severe (11+) | severe |

At session end: create assessment_sessions row, write assessment_items (per question), write assessment_scores (severity + total). Append-only, GDPR-safe via pseudonymous_user_id.

### C. Analytics Events (Anonymized Reporting)

Emit to existing analytics_events table:

```json
{
  "event_type": "assessment_completed",
  "pseudonymous_user_id": "uuid",
  "cohort_id": "uuid-or-null",
  "metadata": {
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
}
```

Enables: severity distribution per cohort, screening completion rates, co-occurrence frequency, screening completeness metrics.

### D. Score Trajectories

Existing materialized view auto-includes new instrument types. Provisional RCI parameters for CX_DEP and CX_ANX (SD, reliability, CMI threshold) to be calibrated after initial data collection. Provisional CMI threshold: 3 points for both.

### E. Risk Threshold Integration

Initial thresholds:

| Instrument | Type | Threshold | Tier |
|------------|------|-----------|------|
| CX_DEP | absolute | {"score": 11} | urgent |
| CX_DEP | item_response | {"item_key": "D18", "min_value": 1} | critical |
| CX_ANX | absolute | {"score": 11} | urgent |
| CX_ANX | item_response | {"item_key": "A05", "min_value": 1} | routine |

Auto-create risk flags via existing threshold evaluation pipeline.

### F. Session-End Webhook Flow

```
1. Extract session parameters from Dialogflow CX
2. IF depression or anxiety playbook was active:
   a. Create assessment_sessions row
   b. Write assessment_items (per question answered)
   c. Write assessment_scores (severity + total)
   d. Evaluate risk thresholds -> create risk_flags if triggered
   e. Schedule next assessment (adaptive interval)
3. Update agent memory (State Timeline entry via existing service)
4. Emit analytics_events (assessment_completed or assessment_abandoned)
```

## Out of Scope

- Changes to the existing Mental Help Assistant Five Acts Reflex framework (only adds handoff instructions)
- Changes to synthetic agent testing framework
- Custom Dialogflow CX webhooks for per-turn scoring (deferred to future upgrade if LLM scoring proves insufficient)
- New frontend UI for viewing CX screening results (existing workbench dashboards may suffice)
- Changes to the chat frontend user experience
- Formal clinical validation of the screening instruments (these are operational protocols, not validated psychometric instruments)
