%dw 2.0
output application/java

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

var effectiveDate = laterDate(vars.row.DateApproved, vars.row.DateRenewed)

var effectiveDateTime =
    if (effectiveDate != null)
        ((effectiveDate as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null

var expirationDate = parseDate(vars.row.DateExpired)

var expirationDateTime =
    if (expirationDate != null)
        ((expirationDate as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null
---
{
    AccountId: vars.accountId,
    AssessmentStatus: "Completed",
    Name: "Universal License Assessment",
    EffectiveDateTime: effectiveDateTime,
    ExpirationDateTime: expirationDateTime,
    Type: "LicensingAndPermitting",
    BusinessLicenseApplication__c: vars.blaId
}
