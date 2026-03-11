# Quickstart: Workbench Tester Tag Assignment UI

## Goal

Validate that the workbench provides a dedicated page for managing the existing `tester` tag, while keeping tester status visible but read-only on user profiles.

## Prerequisites

- Backend and workbench frontend from the same deploy cycle
- At least one account with `Admin`, `Supervisor`, or `Owner` access
- At least one eligible internal or dedicated test account
- At least one regular end-user account for negative validation
- Existing `tester` tag available in the tagging system

## Validation Steps

### 1. Dedicated Page Access

1. Log in as `Admin`, `Supervisor`, or `Owner`
2. Navigate to the dedicated tester tag-management page (`/workbench/users/tester-tags`)
3. Verify the page is accessible
4. Verify the page explains that the `tester` tag is for internal staff or dedicated test accounts only

Expected result:
- Authorized roles can access the page
- Guidance text is visible

### 2. Unauthorized Access

1. Log in as a role below `Supervisor`
2. Attempt to navigate to the dedicated tester tag-management page

Expected result:
- The page is not accessible to unauthorized roles

### 3. Assign Tester Tag To Eligible User

1. Open the dedicated tester tag-management page as an authorized role
2. Select an eligible internal or dedicated test account
3. Assign the `tester` tag
4. Save the change
5. Reload the page
6. Open the same user’s profile

Expected result:
- Save succeeds
- The user now shows as tester-tagged on the management page
- The user profile visibly shows the tester status
- The profile does not allow editing the tester tag directly
- The user profile tester-status section remains read-only and matches the management page after refresh

### 4. Block Assignment To Regular End User

1. Open a regular end-user account in the dedicated management page
2. Attempt to assign the `tester` tag

Expected result:
- The action is blocked
- The UI explains that only eligible internal or dedicated test accounts can receive the tag

### 5. Remove Tester Tag

1. Open a currently tester-tagged eligible user
2. Remove the `tester` tag
3. Save and reload
4. Re-open the user profile

Expected result:
- Save succeeds
- Tester status is removed from the management page and the profile view

### 6. Chat Dependency Check

1. Use a tester-tagged eligible account to access chat
2. Verify tester-only chat behavior that depends on the tag still works
3. Remove the tag and refresh or load a new session

Expected result:
- Tester-tagged behavior is available only while the tag is assigned
- After removal, future relevant chat access no longer behaves as tester-tagged

## Evidence To Capture

- Screenshot of the dedicated tester tag-management page
- Screenshot of a user profile with visible tester status
- Screenshot or trace showing blocked assignment for a regular end-user account
- Screenshot or trace showing unauthorized page access is denied
- Network evidence for successful assign and remove requests

## Implementation Notes

- The workbench route is expected at `/workbench/users/tester-tags`
- The profile view shows tester status as a visible read-only badge plus a read-only tester-status section
- Backend requests are expected under `/api/admin/tester-tags/users`

## Notes

- Tester-tag changes apply on refresh or next relevant session load, not retroactively to already-rendered chat without refresh
- This feature manages only the `tester` tag in this release, even though the page is designed for future expansion
