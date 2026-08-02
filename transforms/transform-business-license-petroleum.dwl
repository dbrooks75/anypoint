%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""

// Zero-pad licenseno to 7 digits for the Name (e.g. "123" -> "0000123")
var licensenoDigits = licenseno as String
var licensenoPaddedFull = "0000000" ++ licensenoDigits
var licensenoPadded = licensenoPaddedFull[(sizeOf(licensenoPaddedFull) - 7) to (sizeOf(licensenoPaddedFull) - 1)]

// PeriodStart = 8/01 of license_issued itself (e.g. license_issued 2026 -> 8/1/2026) - same year, no +1
// license_issued is an Access-exported numeric year column, strip any trailing ".0" artifact same as other numeric columns
var licenseIssuedYear = (vars.row.license_issued default "" splitBy ".")[0]

// PeriodEnd/Expiration_Date__c: Current -> 7/31/2027 if a 2026 deposit_date exists in MercAR for
// this licenseno, else 7/31/2026 (independent of license_issued); Historical -> 7/31 of
// license_issued + 1 year (unchanged rule)
var matchingArRows = vars.mercArRows filter (row) -> (row.licenseno default "") == licenseno

var currentYearArRows = matchingArRows filter (row) ->
    (row.deposit_date default "") != "" and ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"

var hasCurrentYearDeposit = sizeOf(currentYearArRows) > 0

var expirationDateTime =
    if ((vars.row.SourceFileType default "") == "Current")
        ((if (hasCurrentYearDeposit) "2027" else "2026") ++ "-07-31T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else if (licenseIssuedYear != "")
        (((licenseIssuedYear as Number) + 1) as String {format: "0"} ++ "-07-31T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

// PeriodStart/Issue_Date__c year (2026-07-28): Current -> 2026 if a 2026 deposit_date exists in
// MercAR for this licenseno (same hasCurrentYearDeposit check as Expiration_Date__c above), else
// 2025 — independent of license_issued, mirroring Expiration_Date__c's Current-branch pattern one
// year earlier each time (Aug 2026-Jul 2027, or Aug 2025-Jul 2026). Historical -> unchanged,
// still license_issued's own year.
var periodStartYear =
    if ((vars.row.SourceFileType default "") == "Current")
        (if (hasCurrentYearDeposit) "2026" else "2025")
    else licenseIssuedYear

var periodStartDateTime =
    if (periodStartYear != "")
        ((periodStartYear as Number) as String {format: "0"} ++ "-08-01T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

// Issue_Date__c and Insurance_Policy_Issue_Date__c both = same date value as PeriodStart, but
// plain Date (not DateTime) — 2026-07-28: Insurance_Policy_Issue_Date__c switched from date_issued
// (a full M/d/yyyy date) to license_issued (year-only, same source as Expiration Date/Issue
// Date/PeriodStart/PeriodEnd), so it just reuses this same August-1-of-periodStartYear anchor
// instead of parsing its own separate date
var periodStartDate =
    if (periodStartYear != "")
        ((periodStartYear as Number) as String {format: "0"} ++ "-08-01") as Date {format: "yyyy-MM-dd"}
    else null
---
{
    AccountId: vars.accountId,
    Business_License_Application__c: vars.blaId,
    Name: "PET-" ++ licensenoPadded,
    Issue_Date__c: periodStartDate,
    PeriodStart: periodStartDateTime,
    PeriodEnd: expirationDateTime,
    Expiration_Date__c: expirationDateTime,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Status: if ((vars.row.SourceFileType default "") == "Current")
                (if (hasCurrentYearDeposit) "Active" else "Expired")
            else "Expired",
    Legacy_License_Number__c: licenseno,
    Insurance_Company__c: vars.row.insurance_company,
    Insurance_Policy_Issue_Date__c: periodStartDate,
    OwnerId: vars.ownerId
}
