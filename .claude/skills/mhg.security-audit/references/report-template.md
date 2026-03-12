# Security Audit Report Template

## Severity Scale

| Level | Definition | Response Time |
|-------|-----------|---------------|
| CRITICAL | Exploitable now, data breach or account takeover possible | Immediate — same day |
| HIGH | Likely exploitable with moderate effort, significant risk | 24–48 hours |
| MEDIUM | Requires specific conditions or chaining, moderate risk | 1 week |
| LOW | Unlikely exploitation, defense-in-depth improvement | Next sprint |
| INFO | Best practice note, no immediate risk | Backlog |

---

## Finding Format

Each finding uses this format:

```
### [SEVERITY] OWASP-REF — Title

**Location**: `repo/path/to/file.ts:line` or `endpoint`
**Finding**: [What was observed — specific, not generic]
**OWASP**: A01:2021 Broken Access Control  (or API03:2023, ASVS V2.1.1, etc.)
**Evidence**: [Code snippet, command output, or config excerpt — truncate tokens]
**Remediation**: [Specific fix — code change, config update, or Jira task reference]
```

**Example finding:**
```
### [HIGH] A07:2021 — OTP codes not invalidated after use

**Location**: `chat-backend/src/routes/auth.ts:142`
**Finding**: After a successful OTP verification, the code record is not deleted or
marked as used. A replayed OTP within its TTL window authenticates successfully.
**OWASP**: A07:2021 Identification and Authentication Failures
**Evidence**:
  // auth.ts:142 — no deletion after match
  const record = await prisma.otp.findFirst({ where: { email, code } });
  if (record) { return issueToken(email); }
  // record never deleted
**Remediation**: After successful verification, delete the OTP record:
  await prisma.otp.delete({ where: { id: record.id } });
  Add a unique constraint on (email, code) to prevent concurrent replay.
```

---

## Report Structure

### 1. Audit Metadata

```
Security Audit — YYYY-MM-DD
Auditor: Claude Code (mhg.security-audit skill v1.0.0)
Scope: chat-backend, chat-frontend, workbench-frontend, chat-types, chat-infra
Dev API: https://api.dev.mentalhelp.chat
Standards: OWASP Top 10 (2021), OWASP API Security Top 10 (2023), OWASP ASVS Level 1
```

### 2. Executive Summary

```
| Severity | Count |
|----------|-------|
| CRITICAL | N     |
| HIGH     | N     |
| MEDIUM   | N     |
| LOW      | N     |
| INFO     | N     |
| Total    | N     |

CVE advisories: N critical, N high, N moderate (from npm audit)
Passed checks: N / total checks verified clean
```

### 3. CRITICAL and HIGH Findings
*(immediate action required — list all, each in finding format above)*

### 4. MEDIUM Findings
*(list all, each in finding format above)*

### 5. LOW / INFO Findings
*(list all, each in finding format above)*

### 6. Dependency CVEs

```
| Severity | Package | CVE ID | Installed | Fix Version | Repo |
|----------|---------|--------|-----------|-------------|------|
| critical | example | CVE-XXXX-NNNNN | 1.0.0 | 1.0.1 | chat-backend |
```

### 7. Passed Checks
*(explicitly list what was verified clean — provides assurance, not just a gap list)*

```
✅ A02:2021 JWT algorithm — HS256 confirmed, `none` algorithm not allowed
✅ A03:2021 SQL injection — Prisma ORM used throughout, no raw string SQL found
✅ API02:2023 Auth enforcement — all protected routes return 401 without token
...
```

---

## Confluence Page Layout

Use Confluence storage format / markdown compatible with the MCP tool:

```
h1. Security Audit — YYYY-MM-DD

||Field||Value||
|Date|YYYY-MM-DD|
|Auditor|Claude Code (mhg.security-audit v1.0.0)|
|Scope|chat-backend, chat-frontend, workbench-frontend, chat-types, chat-infra|
|Standards|OWASP Top 10 (2021), OWASP API Security Top 10 (2023), OWASP ASVS Level 1|

h2. Executive Summary

||Severity||Count||
|CRITICAL|N|
|HIGH|N|
|MEDIUM|N|
|LOW|N|
|INFO|N|
|*Total*|*N*|

CVE advisories from npm audit: N critical, N high, N moderate

h2. 🔴 CRITICAL / HIGH Findings
[findings here]

h2. 🟡 MEDIUM Findings
[findings here]

h2. 🔵 LOW / INFO Findings
[findings here]

h2. Dependency CVEs
[table here]

h2. ✅ Passed Checks
[checklist here]
```

---

## Notes on Evidence Quality

- **Code snippets**: Include file path and line number; trim to the relevant lines only
- **Command output**: Include the exact command and its exit code; truncate long outputs
- **Headers**: Show the `curl -si` output lines relevant to the finding
- **CVEs**: Always include CVE ID — do not reference advisory without it
- **Unverifiable checks**: Mark as `INFO — Manual review required: <reason>`
- **Tokens / secrets**: Never include in snippets; replace with `[REDACTED]`
