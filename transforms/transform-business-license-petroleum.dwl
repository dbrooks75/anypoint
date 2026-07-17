%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""
var issueDate = vars.row.date_issued default ""

// Zero-pad licenseno to 7 digits for the Name (e.g. "123" -> "0000123")
var licensenoDigits = licenseno as String
var licensenoPaddedFull = "0000000" ++ licensenoDigits
var licensenoPadded = licensenoPaddedFull[(sizeOf(licensenoPaddedFull) - 7) to (sizeOf(licensenoPaddedFull) - 1)]

// Insurance_Policy_Issue_Date__c = date_issued, plain Date (not DateTime)
var issueDateParsed =
    if (issueDate != "")
        (issueDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) as Date {format: "yyyy-MM-dd"}
    else null

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
        ((if (hasCurrentYearDeposit) "2027" else "2026") ++ "-07-31T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else if (licenseIssuedYear != "")
        (((licenseIssuedYear as Number) + 1) as String {format: "0"} ++ "-07-31T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

var periodStartDateTime =
    if (licenseIssuedYear != "")
        ((licenseIssuedYear as Number) as String {format: "0"} ++ "-08-01T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

// Issue_Date__c = same date value as PeriodStart, but plain Date (not DateTime)
var periodStartDate =
    if (licenseIssuedYear != "")
        ((licenseIssuedYear as Number) as String {format: "0"} ++ "-08-01") as Date {format: "yyyy-MM-dd"}
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
    Status: if ((vars.row.SourceFileType default "") == "Current") "Active" else "Inactive",
    Legacy_License_Number__c: licenseno,
    Insurance_Company__c: vars.row.insurance_company,
    Insurance_Policy_Issue_Date__c: issueDateParsed,
}
