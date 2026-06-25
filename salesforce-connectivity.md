# Salesforce Connectivity Setup

## Working Connector Configuration (Basic Authentication)

| Field | Value |
|---|---|
| Connection Type | Basic Authentication |
| Username | `andrew.brooks.vdr@dlt.ri.gov.dp02` |
| Password | your Salesforce password |
| Security Token | in its own field (do NOT append to password) |
| Authorization URL | `https://ridlt--dp02.sandbox.my.salesforce.com` |
| API Version | `59.0` |

## Key Notes

- Use the **custom domain URL** for Authorization URL, not `https://test.salesforce.com` — the org uses My Domain
- API version must be `59.0` — version 65.0 does not support SOAP login
- Security token goes in its **own field**, not appended to the password

## Issues Encountered and Fixes

### 1. Java 17 Module Error
**Error:** `InaccessibleObjectException: Unable to make field private final java.lang.String org.mule.runtime.ast.privileged.error...`

**Cause:** Anypoint Studio 7.21 bundles Java 17 (`org.mule.tooling.jdk.win32.x86_64_1.4.1`), which has stricter module encapsulation.

**Fix:** Add to `AnypointStudio.ini` under `-vmargs`:
```
--add-opens=org.mule.runtime.artifact.ast/org.mule.runtime.ast.privileged.error=ALL-UNNAMED
```

### 2. SOAP Login Not Available at API Version 65.0
**Error:** `soap login operation is not available in the api version specified (65.0)`

**Fix:** Change API Version in connector Advanced tab to `59.0`

### 3. Account Locked Out for API Access
**Symptom:** Browser login works, but API returns `SALESFORCE:INVALID_INPUT` — invalid username, password, security token; or user locked out

**Cause:** Multiple failed connection attempts lock the account for SOAP API access independently of browser login. Visible in Salesforce Login History as "Password Lockout" under Login Type "Other Apex API / SOAP API".

**Fix:**
- Go to Setup → Users → Users → find your user → click **Unlock**
- Then reset your security token: Profile → Settings → My Personal Information → Reset My Security Token

### 4. Security Token Resets After Sandbox Refresh
After every sandbox refresh, the security token is invalidated. Always reset it:
- Profile → Settings → My Personal Information → Reset My Security Token
- Token is emailed to the address on the user record

## AnypointStudio.ini Location
`C:\AnypointStudio\AnypointStudio.ini`

Do not add duplicate `-vm` entries — only one `-vm` and path line should exist.

## OAuth Alternative
If Basic Authentication stops working, switch to OAuth 2.0 via a Connected App. Ask the Salesforce admin to:
1. Create a Connected App with OAuth enabled
2. Set scopes: `api`, `refresh_token`, `offline_access`
3. Provide the Consumer Key and Consumer Secret

Then change the connector Connection type to **OAuth 2.0 Username Password**.
