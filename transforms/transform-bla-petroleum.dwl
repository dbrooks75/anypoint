%dw 2.0
output application/java

var jobno = vars.row.jobno default ""
var licenseno = vars.row.licenseno default ""

// AmountPaid = tot_pymt from the mercAr (MercAR.csv) record with the max deposit_date, matched by licenseno
var matchingArRows = vars.arRows filter (row) -> (row.licenseno default "") == licenseno

var latestArRow = if (sizeOf(matchingArRows) > 0)
    (matchingArRows orderBy (row) -> row.deposit_date as Date {format: "M/d/yyyy"})[-1]
  else null

var amountPaid = if (latestArRow != null) latestArRow.tot_pymt as Number else null
---
{
    AccountId: vars.accountId,
    ApplicationType: if (jobno[-2 to -1] == "01") "New" else "Renewal",
    AmountPaid: amountPaid,
    Status: "Approved",
    // Placeholder — see dev-questions.md for what this should actually be
    AppliedDate: |1900-01-01T00:00:00Z|,
    Category: "License",
    // Placeholder — see dev-questions.md for what Trade__c should be for Petroleum
    Trade__c: "TBD",
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy Job Number: " ++ jobno
}
