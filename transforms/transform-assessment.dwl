%dw 2.0
output application/java

var issueDate = vars.row.issue_date default ""

var issueDateTime =
    if (issueDate != "")
        ((issueDate as Date {format: "MM/dd/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null
---
{
    AccountId: vars.accountId,
    AssessmentStatus: "Completed",
    Name: "Business License Assessment",
    EffectiveDateTime: issueDateTime,
    Type: "LicensingAndPermitting",
    BusinessLicenseApplication__c: vars.blaId
}
