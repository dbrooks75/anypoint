%dw 2.0
import parseDate, noonUtc from usermodules::Utils
output application/java

var coLicenseNo = vars.row.co_license_no default ""

// License period from comp_lic.expire_date (e.g. 08/01/2026):
//   Issue_Date__c / PeriodStart     = expire_date minus one year -> 8/1/2025
//   Expiration_Date__c / PeriodEnd  = expire_date minus one day  -> 7/31/2026
// Blank expire_date -> all four null
var expireDate = parseDate(vars.row.expire_date)
var issueDate = if (expireDate != null) expireDate - |P1Y| else null
var expirationDate = if (expireDate != null) expireDate - |P1D| else null

// License subtype from comp_lic.license_type. A trailing "C" (e.g. "3C") is stripped for now —
// what the C means is an open question
var licenseType = upper(trim(vars.row.license_type default ""))
var licenseTypeBase = if (licenseType endsWith "C") licenseType[0 to -2] else licenseType
var licenseSubtype = {
    "1": "Full License",
    "2": "Handicap",
    "3": "Material Handling",
    "4": "Material Handling + Handicap",
    "AI": "Authorized Inspector"
}[licenseTypeBase]
---
{
    AccountId: vars.accountId,
    Business_License_Application__c: vars.blaId,
    // Name matches License_Number__c, a formula that shows Legacy_License_Number__c when it's
    // populated (co_license_no is never blank)
    Name: coLicenseNo,
    Legacy_License_Number__c: coLicenseNo,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Issue_Date__c: issueDate,
    PeriodStart: noonUtc(issueDate),
    PeriodEnd: noonUtc(expirationDate),
    Expiration_Date__c: noonUtc(expirationDate),
    // Only status "A" rows reach Business License creation, so this is always Active
    Status: if ((vars.row.status default "") == "A") "Active" else null,
    // License_Subtype__c: provisional name, field not yet created in Salesforce — uncomment once it exists
    // License_Subtype__c: licenseSubtype,
    OwnerId: vars.ownerId
}
