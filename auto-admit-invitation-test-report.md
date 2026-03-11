# Auto-Admit Invitation Code Flow Test Report

**Test Date**: 2026-03-05  
**Test URL**: https://dev.mentalhelp.chat  
**Invitation Code**: GATETEST01  
**Test Method**: EMAIL OTP only (no Google)

---

## Executive Summary

**RESULT: ❌ FAIL - Cannot complete test due to backend error**

The auto-admit invitation code flow cannot be tested because the backend OTP verification endpoint is consistently returning HTTP 500 errors. This is a critical backend issue preventing ALL email-based login attempts, regardless of invitation code usage.

---

## Test Attempts

### Attempt 1: Existing Email with Invitation Code
- **Email**: `final-gate-test@mentalhelp.global`
- **URL**: `https://dev.mentalhelp.chat/login?invite=GATETEST01`
- **Invitation Code**: Pre-filled as `GATETEST01`
- **OTP Code**: `675596`
- **Result**: ❌ FAIL
- **Error**: `login.otp.internal_error`
- **HTTP Status**: 500 from `/api/auth/otp/verify`
- **Screenshot**: `step1-verify-error.png`

### Attempt 2: Existing Email with Invitation Code (Retry)
- **Email**: `final-gate-test@mentalhelp.global`
- **URL**: `https://dev.mentalhelp.chat/login?invite=GATETEST01`
- **Invitation Code**: Pre-filled as `GATETEST01`
- **OTP Code**: `680133`
- **Result**: ❌ FAIL
- **Error**: `login.otp.internal_error`
- **HTTP Status**: 500 from `/api/auth/otp/verify`
- **Screenshot**: `step1-second-verify-error.png`

### Attempt 3: Existing Email WITHOUT Invitation Code (Control Test)
- **Email**: `final-gate-test@mentalhelp.global`
- **URL**: `https://dev.mentalhelp.chat/login`
- **Invitation Code**: Empty
- **OTP Code**: `286079`
- **Result**: ❌ FAIL (Different error message)
- **Error**: `Your account is awaiting approval.`
- **HTTP Status**: 500 from `/api/auth/otp/verify`
- **Screenshot**: `step1-without-invite-awaiting-approval.png`
- **Note**: This suggests the account exists in a pending state, but verification still fails with 500 error

### Attempt 4: Fresh Email with Invitation Code
- **Email**: `gate-test-20260305@mentalhelp.global`
- **URL**: `https://dev.mentalhelp.chat/login?invite=GATETEST01`
- **Invitation Code**: Pre-filled as `GATETEST01`
- **OTP Code**: `533797`
- **Result**: ❌ FAIL
- **Error**: `login.otp.internal_error`
- **HTTP Status**: 500 from `/api/auth/otp/verify`
- **Screenshot**: `step1-fresh-email-with-invite-error.png`

---

## Network Analysis

All verification requests follow the same pattern:

```
[POST] /api/auth/otp/send => [200] ✓ Success
[POST] /api/auth/otp/verify => [500] ✗ Internal Server Error
```

**Key Findings**:
- OTP generation works correctly (all send requests return 200)
- OTPs are displayed in dev console logs correctly
- The failure occurs consistently at the verification step
- No response body is visible in network logs (500 error)

---

## Console Errors

All attempts show the same error pattern:

```
[ERROR] Failed to load resource: the server responded with a status of 500 () 
@ https://api.dev.mentalhelp.chat/api/auth/otp/verify:0
```

Additional context errors (expected, related to session cleanup):
- `[401] /api/auth/refresh` - Expected when no valid session exists
- `[401] /api/auth/logout` - Expected after refresh fails

---

## Frontend Behavior

The frontend correctly:
1. ✓ Pre-fills the invitation code from URL query parameter
2. ✓ Sends the invitation code with the OTP send request
3. ✓ Displays the OTP verification form
4. ✓ Shows appropriate error messages

Error messages observed:
- **With invitation code**: `login.otp.internal_error` (translation key shown as-is)
- **Without invitation code**: `Your account is awaiting approval.` (proper message)

---

## Root Cause Analysis

**Backend Issue**: The `/api/auth/otp/verify` endpoint is experiencing internal server errors that prevent any email-based login from completing, regardless of:
- Whether an invitation code is present
- Whether the email is new or existing
- Which specific OTP code is used

**Hypothesis**: The backend may be encountering an issue when:
1. Processing the invitation code during verification, OR
2. Auto-admitting the user to a group, OR
3. Creating/updating user records, OR
4. Validating the invitation code against the database

---

## Test Coverage Status

| Test Step | Status | Notes |
|-----------|--------|-------|
| Step 1.1: Navigate with invite code | ✓ PASS | URL parameter pre-fills correctly |
| Step 1.2: Switch to English | ✓ PASS | Language switching works |
| Step 1.3: Enter email | ✓ PASS | Email input works |
| Step 1.4: Invitation code pre-filled | ✓ PASS | GATETEST01 pre-filled |
| Step 1.5: Send OTP | ✓ PASS | OTP generated and displayed |
| Step 1.6: Enter OTP | ✓ PASS | OTP input works |
| Step 1.7: Verify OTP | ❌ FAIL | Backend 500 error |
| Step 1.8: Auto-admit redirect | ⏸️ BLOCKED | Cannot test due to Step 1.7 failure |
| Step 2: Survey gate | ⏸️ BLOCKED | Cannot reach after login |
| Step 3: Partial save | ⏸️ BLOCKED | Cannot test survey without login |

---

## Recommendations

### Immediate Action Required
1. **Backend Team**: Investigate `/api/auth/otp/verify` endpoint for 500 errors
   - Check error logs for detailed stack traces
   - Verify database queries related to invitation code validation
   - Check user creation/update logic during auto-admit
   - Verify invitation code `GATETEST01` exists and is properly configured

2. **Frontend**: The translation key `login.otp.internal_error` should be properly translated in the English locale

### Next Steps After Fix
Once the backend issue is resolved:
1. Rerun this test with a fresh email
2. Verify auto-admit redirects to home/chat page (not "awaiting approval")
3. Test survey gate appearance
4. Test partial save functionality
5. Test survey completion flow

---

## Evidence Files

- `step1-verify-error.png` - First verification error with `final-gate-test@mentalhelp.global`
- `step1-second-verify-error.png` - Second verification error (retry)
- `step1-without-invite-awaiting-approval.png` - Control test without invitation code
- `step1-fresh-email-with-invite-error.png` - Fresh email with invitation code error
- `network-requests-verify-error.txt` - Network log from first attempt
- `network-requests-second-verify.txt` - Network log from second attempt
- `console-2026-03-05T08-51-21-369Z.log` - Console logs from main test session

---

## Test Environment

- **Frontend**: https://dev.mentalhelp.chat
- **Backend API**: https://api.dev.mentalhelp.chat
- **Browser**: Chromium (via Playwright)
- **Test Framework**: Playwright MCP
- **Date**: March 5, 2026
