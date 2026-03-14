# Quickstart: Survey Instance Management (029)

**Branch**: `029-survey-management` | **Date**: 2026-03-14

## Prerequisites

- Access to the workbench at `https://workbench.dev.mentalhelp.chat`
- An account with `SURVEY_INSTANCE_MANAGE` or `SURVEY_INSTANCE_VIEW` permission
- At least one published survey schema
- At least one survey instance in `active` or `expired` status
- At least one group with active members

## Feature 1: Edit Expiration Date

### In the Workbench UI
1. Navigate to **Surveys → Instances**
2. Click on an active or expired survey instance
3. Click the **Edit** button (pencil icon) in the instance detail header
4. In the edit form, locate the **Expiration Date** field
5. Select a new future datetime
6. Click **Save**
7. The instance detail refreshes — verify the new expiration date is shown
8. If the instance was previously expired, verify the status badge now shows **ACTIVE**

### Via API (curl)
```bash
curl -X PATCH https://api.dev.mentalhelp.chat/workbench/survey-instances/{INSTANCE_ID} \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{ "expirationDate": "2026-04-30T23:59:59Z" }'
```

Expected response: `{ "success": true, "data": { ...SurveyInstance with updated expirationDate } }`

## Feature 2: Change Group Assignment Mid-Flight

### In the Workbench UI
1. Navigate to **Surveys → Instances**
2. Click on an active survey instance that has at least one existing response
3. Click the **Edit** button in the instance detail header
4. In the edit form, locate the **Groups** multi-select
5. Deselect current group(s) and select the new target group(s)
6. Click **Save**
7. Verify the instance detail shows the updated group(s)
8. Navigate to the **Responses** tab — verify existing responses from the old group are still visible
9. Log in as a user from the new group and verify the survey appears in their pending list

### Via API (curl)
```bash
curl -X PATCH https://api.dev.mentalhelp.chat/workbench/survey-instances/{INSTANCE_ID} \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{ "groupIds": ["NEW_GROUP_UUID"] }'
```

Expected response: `{ "success": true, "data": { ...SurveyInstance with updated groupIds } }`

## Feature 3: View Completion Statistics

### In the Workbench UI
1. Navigate to **Surveys → Instances**
2. Click on a survey instance
3. Click the **Statistics** tab (or button) in the instance detail view
4. Review the summary: total members, completed, pending, completion rate
5. In the **Non-Completers** section, view the list of users who have not submitted
6. If the instance spans multiple groups, a group selector or group tabs shows stats per group

### Via API (curl)
```bash
# All groups
curl https://api.dev.mentalhelp.chat/workbench/survey-instances/{INSTANCE_ID}/statistics \
  -H "Authorization: Bearer {TOKEN}"

# Single group
curl "https://api.dev.mentalhelp.chat/workbench/survey-instances/{INSTANCE_ID}/statistics?groupId={GROUP_ID}" \
  -H "Authorization: Bearer {TOKEN}"
```

Expected response structure:
```json
{
  "success": true,
  "data": {
    "instanceId": "...",
    "groups": [
      {
        "groupId": "...",
        "groupName": "Therapy Group A",
        "totalMembers": 10,
        "completedCount": 7,
        "pendingCount": 3,
        "completionRate": 0.7,
        "members": [
          { "userId": "...", "displayName": "Alice Smith", "email": "...", "isComplete": true, "completedAt": "..." },
          { "userId": "...", "displayName": "Bob Jones", "email": "...", "isComplete": false, "completedAt": null }
        ]
      }
    ]
  }
}
```

## Validation Checks

| Scenario | Expected Behaviour |
|----------|-------------------|
| Set expiration to past date | 400 error with `VALIDATION_ERROR` code |
| PATCH with no fields | 400 error with `VALIDATION_ERROR` code |
| PATCH closed instance | 409 error with `INSTANCE_CLOSED` code |
| PATCH with empty groupIds array | 400 error with `VALIDATION_ERROR` code |
| Statistics for expired instance | Returns data (historical stats still accessible) |
| Statistics for group not assigned to instance | 400 error |
