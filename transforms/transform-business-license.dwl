%dw 2.0
output application/java

var jobno = vars.row.jobno default ""
var issueDate = vars.row.issue_date default ""

var issueDateParsed = issueDate as Date {format: "MM/dd/yyyy"}

var issueDateTime =
    if (issueDate != "")
        ((issueDate as Date {format: "MM/dd/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

var firstOfMonth = (issueDateParsed as String {format: "yyyy-MM"} ++ "-01") as Date {format: "yyyy-MM-dd"}
var lastDayPrevMonth = firstOfMonth - |P1D|
var expirationDate = lastDayPrevMonth + |P1Y|

var expirationDateTime =
    if (issueDate != "")
        ((expirationDate as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null
---
{
    AccountId: vars.accountId,
    Business_License_Application__c: vars.blaId,
    Name: "CS-" ++ jobno,
    Issue_Date__c: issueDateTime,
    PeriodStart: issueDateTime,
    PeriodEnd: expirationDateTime,
    Expiration_Date__c: expirationDateTime,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Status: if ((vars.row.SourceFileType default "") == "Current") "Verified" else "Inactive",
    Legacy_License_Number__c: jobno,
}
