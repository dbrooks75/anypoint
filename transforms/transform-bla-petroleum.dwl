%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""

// AmountPaid = tot_pymt_amt from the MercAR.csv record with the max deposit_date, matched by licenseno
var matchingArRows = vars.mercArRows filter (row) -> (row.licenseno default "") == licenseno

var latestArRow = if (sizeOf(matchingArRows) > 0)
    (matchingArRows orderBy (row) -> row.deposit_date as Date {format: "M/d/yyyy"})[-1]
  else null

var amountPaid = if (latestArRow != null) latestArRow.tot_pymt_amt as Number else null

// Status: Current-year records are Approved only if AR shows a 2026 deposit_date; Historical is always Approved
var currentYearArRows = matchingArRows filter (row) ->
    (row.deposit_date default "") != "" and ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"

var hasCurrentYearDeposit = sizeOf(currentYearArRows) > 0

var status = if ((vars.row.SourceFileType default "") == "Current")
        (if (hasCurrentYearDeposit) "Approved" else "Draft")
    else "Approved"

var insExpireDate = vars.row.ins_expire_date default ""

var insExpireDateParsed =
    if (insExpireDate != "")
        (insExpireDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) as Date {format: "yyyy-MM-dd"}
    else null
---
{
    AccountId: vars.accountId,
    ApplicationType: "New",
    AmountPaid: amountPaid,
    Status: status,
    // Placeholder — see dev-questions.md for what this should actually be
    AppliedDate: |1900-01-01T00:00:00Z|,
    Category: "License",
    // Placeholder — see dev-questions.md for what Trade__c should be for Petroleum
    Trade__c: "TBD",
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy License Number: " ++ licenseno,
    Policy_Expiration_Date__c: insExpireDateParsed,
    PrimaryOwnerId: vars.contactId
}
