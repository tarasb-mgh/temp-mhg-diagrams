# Global Role Group Access — Design Spec

**Date:** 2026-03-19
**Status:** Draft
**Feature:** Global role holders access group-specific workbench functionality without group membership

---

## Problem Statement

The MHG workbench gates group-specific functionality (review queues, group configuration, analytics) on group membership. Group membership is a chat-user concept — ordinary users are added to groups to participate in chat sessions. Global role holders (Researcher, Moderator, Supervisor, Owner) use the workbench for cross-group oversight but are blocked from group-scoped operations unless manually added as members of each group. This is both tedious and semantically incorrect — it conflates oversight roles with regular participation and pollutes group member lists.

## Goal

Global role holders can access all group-scoped workbench functionality for any group without being group members. Group member lists remain unaffected — only actual chat users appear as members.

**Affected roles:** Researcher, Moderator, Supervisor, Owner (all global workbench roles above QA Specialist).

## Approach: Two-Tier Access Resolution

Replace direct group-membership checks with a two-tier access resolution function:

```
canAccessGroup(userId, groupId) →
  (1) user is an explicit member of the group   — chat users
  OR
  (2) user holds a global role >= Researcher     — workbench users
```

### Where This Applies

- **Review queue group filter** — global roles can filter/view sessions from any group
- **Group configuration panels** — global roles can view and modify supervision policy, reviewer counts, survey ordering for any group
- **Group member lists** — global roles can view members of any group (but do NOT appear in those lists themselves)
- **Group-scoped analytics/dashboards** — global roles can view metrics for any group
- **Survey management** — global roles can manage survey assignments across groups

### Where This Does NOT Apply

- **Chat participation** — only actual group members participate in chat sessions (no change)
- **Group member list contents** — global role holders are never listed as group members
- **QA Specialists** — they remain gated by explicit group membership (lowest workbench role, works within assigned groups only)

### Role Threshold

The cutoff is QA Specialist (group-scoped) vs Researcher and above (platform-wide). This aligns with the existing `REVIEW_CROSS_GROUP` permission boundary from spec 028.

## Behavioral Rules

1. **Full functional access, not just read access.** A global Supervisor accessing a group they don't belong to can do everything in that group's workbench — edit supervision policy, adjust reviewer counts, reorder surveys — not just view data. Access resolution grants the same functional scope as membership.

2. **Role permissions still apply.** Access resolution removes the membership gate, but the role's own permission set still governs what actions are available. A Researcher can access any group's review queue but cannot create tags (that requires Supervisor+). The role hierarchy is unchanged.

3. **No phantom memberships.** Global role holders never appear in `group_memberships` data. API endpoints that return group member lists exclude implicit-access users. `canAccessGroup` is an access check, not a membership record.

4. **Audit trail attribution.** When a global role holder performs an action in a group they don't belong to, the audit log captures both the user identity and the fact that access was via global role (not membership). This supports compliance and traceability.

5. **Group selector shows all groups.** In the workbench UI, the group filter/dropdown for global role holders lists all groups in the system, not just groups they're members of. QA Specialists continue to see only their assigned groups.

## Edge Cases

| Edge Case | Behavior |
|-----------|----------|
| **Role downgrade** (Researcher → QA Specialist) | Immediate loss of implicit access to non-member groups. Access resolution is evaluated at request time — no cached membership to clean up. |
| **Global role holder who is also an explicit group member** | No conflict. `canAccessGroup` returns true via membership path. They appear in the group member list as a regular member. If their global role is later removed, they retain access through membership. Both paths are independent. |
| **Group deletion or archival** | Implicit access follows the group's lifecycle. If a group is archived or deleted, global role holders lose access the same way members do. No special handling needed. |
| **Empty group list for QA Specialist** | A QA Specialist with no group memberships sees an empty group selector and cannot access any group-scoped workbench features. Correct behavior — they must be explicitly assigned. |
| **API authorization vs UI visibility** | Both must be updated. The backend API must enforce `canAccessGroup` server-side. UI-only changes are insufficient. |

## Scope Boundaries

### In Scope

- New `canAccessGroup` access resolution function (backend)
- Refactor all group-membership gates in workbench API endpoints to use `canAccessGroup`
- Update workbench UI group selector to show all groups for Researcher+ roles
- Audit log entries to distinguish membership-based vs role-based access
- Backend authorization tests for both access paths

### Out of Scope

- Chat frontend — no changes (membership-gated as before)
- QA Specialist role behavior — unchanged, remains group-membership-gated
- Group membership CRUD — no changes to how members are added/removed
- New UI for managing implicit access — there's nothing to manage; it's automatic from the role
- Role hierarchy changes — no new roles or permission reshuffling
- Delivery workbench (spec 033) — separate single-environment tool with IAP auth, unrelated

## Success Criteria

1. A Researcher with zero group memberships can select any group in the workbench and perform all Researcher-permitted actions
2. A Supervisor can modify supervision policy for any group without being a member
3. An Owner can access all group-scoped features across all groups
4. A QA Specialist without group memberships sees an empty group selector and cannot access group-scoped features
5. Group member list API endpoints never return global-role-only users
6. Audit logs distinguish role-based group access from membership-based access
