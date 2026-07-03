%dw 2.0
output application/java

var jobno = vars.row.jobno default ""
var issueDate = vars.row.issue_date default ""

var issueDateTime =
    if (issueDate != "")
        ((issueDate as Date {format: "MM/dd/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null
---
{
    AccountId: vars.accountId,
    ApplicationType: if (jobno[-2 to -1] == "01") "New" else "Renewal",
    AmountPaid: if ((vars.row.tot_pymt default "") != "") vars.row.tot_pymt as Number else null,
    Status: "Approved",
    AppliedDate: issueDateTime,
    Category: "License",
    Trade__c: "Labor Standards",
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy Job Number: " ++ jobno
}
