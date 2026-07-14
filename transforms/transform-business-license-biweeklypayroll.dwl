%dw 2.0
output application/java

var rid = vars.row.RID default ""

fun parseDate(d) = if ((d default "") != "") d as Date {format: "M/d/yyyy"} else null

fun laterDate(a, b) = do {
    var da = parseDate(a)
    var db = parseDate(b)
    ---
    if (da == null and db == null) null
    else if (da == null) db
    else if (db == null) da
    else if (da >= db) da else db
}

fun toDateTime(d) =
    if (d == null) null
    else ((d as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}

var issueDate = laterDate(vars.row.DateApproved, vars.row.DateRenewed)
var periodEndDate = laterDate(vars.row.DateExpired, vars.row.DateRevoked)

var issueDateTime = toDateTime(issueDate)
var periodEndDateTime = toDateTime(periodEndDate)

var expiredDate = parseDate(vars.row.DateExpired)
var status = if (expiredDate == null or (now() as Date) < expiredDate) "Verified" else "Inactive"
---
{
    AccountId: vars.accountId,
    Business_License_Application__c: vars.blaId,
    Name: "BW-" ++ rid,
    Issue_Date__c: issueDateTime,
    PeriodStart: issueDateTime,
    PeriodEnd: periodEndDateTime,
    Expiration_Date__c: null,
    RegulatoryAuthorizationTypeId: vars.licenseTypeId,
    Status: status,
    Legacy_License_Number__c: rid
}
