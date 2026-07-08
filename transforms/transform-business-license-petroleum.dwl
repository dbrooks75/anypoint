%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""
var issueDate = vars.row.date_issued default ""

var issueDateParsed = issueDate as Date {format: "M/d/yyyy"}

var issueDateTime =
    if (issueDate != "")
        ((issueDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
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
    Name: "CS-" ++ licenseno,
    Issue_Date__c: issueDateTime,
    PeriodStart: issueDateTime,
    PeriodEnd: expirationDateTime,
    Expiration_Date__c: expirationDateTime,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Status: if ((vars.row.SourceFileType default "") == "Current") "Active" else "Inactive",
    Legacy_License_Number__c: licenseno,
}
