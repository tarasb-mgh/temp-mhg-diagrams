# 5. Data Flow & Integration Map

**What this is:** How a request (and a conversation) moves through the entire system end-to-end.

---

## User Request Flow

```mermaid
flowchart TB
    USER["User opens mentalhelp.chat"]
    DNS["Cloud DNS\nresolve mentalhelp.chat"]
    GCLB["Global HTTPS LB"]
    GCS["Cloud Storage\nchat-frontend-prod"]
    APP["React SPA loads"]
    API_CALL["API call to api.mentalhelp.chat"]
    CR["Cloud Run\nchat-backend-prod"]
    AUTH["Authenticate (JWT / OTP)"]
    ROUTE["Express route handler"]
    CX_API["Dialogflow CX API v3"]
    CX_AGENT["Dialogflow CX Agent"]
    VA["Vertex AI\ngemini-2.5-flash"]
    RESPONSE["Agent response"]
    USER_END["User sees response"]

    USER --> DNS
    DNS --> GCLB
    GCLB --> GCS
    GCS --> APP
    APP --> API_CALL
    API_CALL --> GCLB
    GCLB --> CR
    CR --> AUTH
    AUTH --> ROUTE
    ROUTE --> CX_API
    CX_API --> CX_AGENT
    CX_AGENT --> VA
    VA --> CX_AGENT
    CX_AGENT --> RESPONSE
    RESPONSE --> CR
    CR --> APP
    APP --> USER_END
```

---

## Conversation Persistence Flow

```mermaid
flowchart LR
    USER_MSG["User message"]
    BACKEND["chat-backend"]
    CX_SESSION["Dialogflow CX Session"]
    GCS_STATE["Cloud Storage\nState Timeline"]
    SQL_ASSESS["Cloud SQL\nStructured Assessments"]
    REVIEW_Q["Workbench Review Queue"]
    REVIEWER["Human Reviewer"]
    DB_UPDATE["Database Update"]

    USER_MSG --> BACKEND
    BACKEND --> CX_SESSION
    CX_SESSION --> GCS_STATE
    CX_SESSION --> SQL_ASSESS
    SQL_ASSESS --> REVIEW_Q
    REVIEW_Q --> REVIEWER
    REVIEWER --> DB_UPDATE
```

---

## Survey Deployment Flow

```mermaid
flowchart TB
    WB_USER["Workbench User"]
    SCHEMA["Create Survey Schema"]
    PUBLISH["Publish Schema"]
    INSTANCE["Deploy Instance"]
    END_USER["End User"]
    TAKE["Take Survey"]
    RESPONSES["Store Responses"]
    SQL["Cloud SQL"]
    ANALYTICS["Analytics / Reports"]

    WB_USER --> SCHEMA
    SCHEMA --> PUBLISH
    PUBLISH --> INSTANCE
    INSTANCE --> END_USER
    END_USER --> TAKE
    TAKE --> RESPONSES
    RESPONSES --> SQL
    SQL --> ANALYTICS
```

---

## Integration Points

| From | To | Protocol | Purpose | Auth Method |
|---|---|---|---|---|
| chat-frontend | chat-backend | HTTPS REST | API calls | HTTP-only cookie (JWT) |
| chat-backend | Dialogflow CX | HTTPS REST (v3) | Agent conversation | Service account (WIF) |
| Dialogflow CX | Vertex AI | Internal GCP | LLM inference | Implicit (same project) |
| Dialogflow CX | chat-backend | HTTPS POST | Session-end webhook | No auth (internal) |
| chat-backend | Cloud SQL | TCP (Cloud SQL proxy) | Data persistence | IAM database auth |
| chat-backend | Secret Manager | HTTPS | Secret retrieval | Service account |
| workbench-frontend | chat-backend | HTTPS REST | Admin/review API | HTTP-only cookie (JWT) |
| GitHub Actions | GCP | OIDC (WIF) | Deploy resources | Workload Identity Federation |

---

**Last Verified:** 2026-05-08 by Taras Bobrovytskyi
**Regeneration:** Code inspection of chat-backend routes + Dialogflow CX flow definitions.
