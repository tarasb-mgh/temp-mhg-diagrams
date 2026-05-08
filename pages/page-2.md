# 2. Production Network Topology

**What this is:** How user traffic enters the system, how it is routed, and where it terminates.

---

## Ingress Flow

```mermaid
flowchart TB
    USER["User"]
    DNS["Cloud DNS\n(mentalhelp.chat)"]
    GCLB["Global HTTPS Load Balancer"]
    CERT["Managed SSL Certificate"]

    subgraph Frontends["Frontend Hosting"]
        GCS_CHAT["GCS Bucket\nchat-frontend-prod"]
        GCS_WB["GCS Bucket\nworkbench-frontend-prod"]
        GCS_DEL["GCS Bucket\ndelivery-workbench-frontend-prod"]
    end

    subgraph Backends["API Backends"]
        CR["Cloud Run\nchat-backend-prod"]
        CR_DEL["Cloud Run\ndelivery-workbench-backend-prod"]
        CR_MCP["Cloud Run\nmcp-server-prod"]
    end

    USER -->|HTTPS request| DNS
    DNS -->|resolve to| GCLB
    GCLB -->|SSL termination| CERT
    GCLB -->|host: mentalhelp.chat| GCS_CHAT
    GCLB -->|host: workbench.mentalhelp.chat| GCS_WB
    GCLB -->|host: delivery.mentalhelp.chat| GCS_DEL
    GCLB -->|host: api.mentalhelp.chat| CR
    GCLB -->|host: api.delivery.mentalhelp.chat| CR_DEL
    GCLB -->|host: mcp.mentalhelp.chat| CR_MCP
```

---

## Domain Mapping

| Canonical URL | Purpose | Backend Type | Backend Resource |
|---|---|---|---|
| https://mentalhelp.chat | Chat frontend | GCS Bucket | chat-frontend-prod |
| https://workbench.mentalhelp.chat | Workbench frontend | GCS Bucket | workbench-frontend-prod |
| https://delivery.mentalhelp.chat | Delivery workbench frontend | GCS Bucket | delivery-workbench-frontend-prod |
| https://api.mentalhelp.chat | Chat backend API | Cloud Run | chat-backend-prod |
| https://api.delivery.mentalhelp.chat | Delivery backend API | Cloud Run | delivery-workbench-backend-prod |
| https://mcp.mentalhelp.chat | MCP server | Cloud Run | mcp-server-prod |

---

## DNS Configuration

| Domain | Type | Purpose |
|---|---|---|
| mentalhelp.chat | A / CNAME | Primary domain — resolves to GCLB frontend IP |
| *.mentalhelp.chat | CNAME | Wildcard for subdomains |

---

**Last Verified:** 2026-05-08 by Taras Bobrovytskyi
**Regeneration:** `gcloud dns record-sets list --zone=mentalhelp-chat --project mental-help-global-25` (requires gcloud auth)
