%dw 2.0
output application/java

var jobno = vars.row.jobno default ""
var issueDate = vars.row.issue_date default ""

var issueDateParsed = issueDate as Date {format: "M/d/yyyy"}

var issueDateTime =
    if (issueDate != "")
        ((issueDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

var firstOfMonth = (issueDateParsed as String {format: "yyyy-MM"} ++ "-01") as Date {format: "yyyy-MM-dd"}
var lastDayPrevMonth = firstOfMonth - |P1D|
var expirationDate = lastDayPrevMonth + |P1Y|

var expirationDateTime =
    if (issueDate != "")
        ((expirationDate as String {format: "yyyy-MM-dd"}) ++ "T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

// Status: mirrors transform-business-license-petroleum.dwl's rule (2026-08-04) — Historical is
// always Expired (was Inactive); Current is Active only if a 2026 deposit_date exists for this
// jobno in vars.laborArRows, else Expired (was unconditionally Active). Own local copy of the
// AR-matching logic since each transform file is standalone, no shared vars across files.
var matchingArRows = vars.laborArRows filter (row) -> (row.jobno default "") == jobno

var currentYearArRows = matchingArRows filter (row) ->
    (row.deposit_date default "") != "" and ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"

var hasCurrentYearDeposit = sizeOf(currentYearArRows) > 0

var status = if ((vars.row.SourceFileType default "") == "Current")
        (if (hasCurrentYearDeposit) "Active" else "Expired")
    else "Expired"
---
{
    AccountId: vars.accountId,
    Business_License_Application__c: vars.blaId,
    Name: jobno,
    Issue_Date__c: issueDateTime,
    PeriodStart: issueDateTime,
    PeriodEnd: expirationDateTime,
    Expiration_Date__c: expirationDateTime,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Status: status,
    Legacy_License_Number__c: jobno,
    OwnerId: vars.ownerId
}
