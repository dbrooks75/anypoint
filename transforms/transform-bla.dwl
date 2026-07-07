%dw 2.0
output application/java

var jobno = vars.row.jobno default ""
---
{
    AccountId: vars.accountId,
    ApplicationType: if (jobno[-2 to -1] == "01") "New" else "Renewal",
    // Jewelry: hardcoded to 0. Original formula: if ((vars.row.tot_pymt default "") != "") vars.row.tot_pymt as Number else null
    AmountPaid: 0,
    Status: "Approved",
    // Placeholder — see dev-questions.md for what this should actually be
    AppliedDate: |1900-01-01T00:00:00Z|,
    Category: "License",
    Trade__c: "Labor Standards",
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy Job Number: " ++ jobno
}
