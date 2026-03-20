# Security Configuration API Contracts

**Feature**: 035-dynamic-permissions-engine

All endpoints prefixed with `/api/security/`. All require authentication + membership in Owners or Security Admins principal group.

## Principal Groups

### GET /api/security/principal-groups
List all principal groups with member counts.

**Response 200**:
```json
{
  "groups": [
    {
      "id": "uuid",
      "name": "Researchers",
      "description": "Senior review and analysis team",
      "isSystem": true,
      "isImmutable": false,
      "memberCount": 5,
      "createdAt": "ISO-8601",
      "updatedAt": "ISO-8601"
    }
  ]
}
```

### POST /api/security/principal-groups
Create a new principal group.

**Request**:
```json
{ "name": "Survey Managers", "description": "Can manage surveys across all groups" }
```

**Response 201**: Created group object.
**Error 400**: `{ "error": { "code": "DUPLICATE_NAME", "message": "..." } }` — name already exists.

### PATCH /api/security/principal-groups/:id
Update group name/description.

**Request**: `{ "name": "...", "description": "..." }` (partial update)
**Response 200**: Updated group object.
**Error 400**: `IMMUTABLE_GROUP` — cannot rename immutable groups.

### DELETE /api/security/principal-groups/:id
Delete a principal group and all its assignments.

**Response 204**: Deleted.
**Error 400**: `IMMUTABLE_GROUP` — cannot delete Owners or Security Admins.

### GET /api/security/principal-groups/:id/members
List members of a principal group.

**Response 200**:
```json
{
  "members": [
    { "userId": "uuid", "email": "user@example.com", "displayName": "John", "createdAt": "ISO-8601" }
  ]
}
```

### POST /api/security/principal-groups/:id/members
Add a user to a principal group.

**Request**: `{ "email": "user@example.com" }`
**Response 201**: Added member object.
**Error 404**: `USER_NOT_FOUND` — email not in system.
**Error 409**: `ALREADY_MEMBER` — user already in group.

### DELETE /api/security/principal-groups/:id/members/:userId
Remove a user from a principal group.

**Response 204**: Removed.
**Error 400**: `LAST_MEMBER` — cannot remove last member of immutable group.

## Permissions

### GET /api/security/permissions
List all registered permissions.

**Query params**: `?category=review` (optional filter)

**Response 200**:
```json
{
  "permissions": [
    {
      "id": "uuid",
      "key": "review:submit",
      "displayName": "Submit Reviews",
      "category": "review",
      "scopeTypes": ["platform", "group"],
      "isSystem": true
    }
  ]
}
```

### GET /api/security/permissions/:id/assignments
List all assignments for a specific permission.

**Response 200**:
```json
{
  "assignments": [
    {
      "id": "uuid",
      "principalType": "group",
      "principalId": "uuid",
      "principalName": "Researchers",
      "securableType": "platform",
      "securableId": null,
      "securableName": "Platform",
      "effect": "allow",
      "createdBy": "uuid",
      "createdAt": "ISO-8601"
    }
  ]
}
```

## Permission Assignments

### GET /api/security/assignments
List assignments filtered by scope.

**Query params**: `?securableType=platform` or `?securableType=group&securableId=<uuid>`

**Response 200**: Array of assignment objects (same shape as above).

### POST /api/security/assignments
Create a permission assignment.

**Request**:
```json
{
  "permissionId": "uuid",
  "principalType": "user",
  "principalId": "uuid",
  "securableType": "platform",
  "securableId": null,
  "effect": "allow"
}
```

**Response 201**: Created assignment object.
**Error 400**: `SCOPE_MISMATCH` — permission doesn't support this scope type.
**Error 400**: `DUPLICATE_ASSIGNMENT` — identical assignment already exists.

### DELETE /api/security/assignments/:id
Remove a permission assignment.

**Response 204**: Deleted.

## Effective Permissions

### GET /api/security/effective/:userId
Get resolved permissions for a user with source attribution.

**Response 200**:
```json
{
  "userId": "uuid",
  "displayName": "John",
  "resolvedAt": "ISO-8601",
  "platform": [
    {
      "permissionKey": "review:submit",
      "effect": "allow",
      "sources": [
        { "type": "group", "id": "uuid", "name": "Researchers", "effect": "allow" }
      ]
    }
  ],
  "groups": {
    "<groupId>": [
      {
        "permissionKey": "group:view_chats",
        "effect": "allow",
        "sources": [
          { "type": "group", "id": "uuid", "name": "Group A Reviewers", "effect": "allow" }
        ]
      }
    ]
  }
}
```

## Settings

### GET /api/security/settings
Get security settings (feature flag state).

**Response 200**:
```json
{ "dynamicPermissionsEnabled": false }
```

### PATCH /api/security/settings
Update security settings.

**Request**: `{ "dynamicPermissionsEnabled": true }`
**Response 200**: Updated settings.

### POST /api/security/cache/invalidate
Force invalidate all permission caches.

**Response 200**: `{ "invalidated": true, "timestamp": "ISO-8601" }`

## Error Format

All errors follow the existing pattern:
```json
{ "success": false, "error": { "code": "ERROR_CODE", "message": "Human-readable message" } }
```
