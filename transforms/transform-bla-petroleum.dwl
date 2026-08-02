%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""

// zip is an Access-exported numeric column, same leading-zero-loss/trailing-".0" risk as
// jobno/ReferenceNumber elsewhere — strip any decimal artifact, then zero-pad back to 5 digits
// (e.g. "2907" -> "02907"), 2026-07-28
fun padZip(z) = do {
    var stripped = (z default "" splitBy ".")[0]
    var len = sizeOf(stripped)
    ---
    if (stripped == "") ""
    else if (len < 5) ("00000"[0 to (4 - len)] ++ stripped)
    else stripped
}

var matchingArRows = vars.mercArRows filter (row) -> (row.licenseno default "") == licenseno

var latestArRow = if (sizeOf(matchingArRows) > 0)
    (matchingArRows orderBy (row) -> row.deposit_date as Date {format: "M/d/yyyy"})[-1]
  else null

var applicationType = if (sizeOf(matchingArRows) > 0) "Renewal" else "New"

// Status: Current-year records are Approved only if AR shows a 2026 deposit_date; Historical is always Approved
var currentYearArRows = matchingArRows filter (row) ->
    (row.deposit_date default "") != "" and ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"

var hasCurrentYearDeposit = sizeOf(currentYearArRows) > 0

var status = if ((vars.row.SourceFileType default "") == "Current")
        (if (hasCurrentYearDeposit) "Approved" else "Draft")
    else "Approved"

// AmountPaid: 0 if Status is Draft; otherwise tot_pymt_amt from the MercAR.csv record with the
// max deposit_date, matched by licenseno (2026-07-28, supersedes the earlier status-independent rule)
var amountPaid = if (status == "Draft") 0 else (if (latestArRow != null) latestArRow.tot_pymt_amt as Number else null)

var insExpireDate = vars.row.ins_expire_date default ""

var insExpireDateParsed =
    if (insExpireDate != "")
        (insExpireDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) as Date {format: "yyyy-MM-dd"}
    else null

// SiteAddress = the Mailing address, same PO-Box-detection logic as transform-address.dwl's
// isMailing branch, just always resolved to Mailing here (no addressType variable to check)
var add1 = vars.row.add1 default ""
var add2 = vars.row.add2 default ""
var hasPOBox1 = (lower(add1) replace "." with "") contains "po box"
var hasPOBox2 = (lower(add2) replace "." with "") contains "po box"
var bothPopulated = (add1 != "") and (add2 != "")

var mailingStreet =
    if (bothPopulated and (hasPOBox1 or hasPOBox2))
        if (hasPOBox1) add1 else add2
    else if (bothPopulated)
        add1 ++ " " ++ add2
    else
        if (add1 != "") add1 else add2

// Omni_JSON_Data__c: AnswerList JSON built from vars.aqrQuestions (see
// transform-aqr-questions-petroleum.dwl), computed before this transform runs. MultiSelect
// answers are reshaped from the semicolon-joined string the AQR record needs into a real JSON
// array — unconfirmed delimiter assumption ("; "), matches
// transform-aqr-questions-biweeklypayroll.dwl's normalizePaymentMethods joinBy.
fun jsonValue(q) =
    if (q.dataType == "MultiSelect" and q.value != null) (q.value as String splitBy "; ")
    else q.value

var omniJsonData = write(
    { AnswerList: vars.aqrQuestions map (q) -> {
        value: jsonValue(q),
        dataType: q.dataType,
        answeredIndex: q.answeredIndex,
        category: q.category,
        questionText: q.questionText,
        versionId: q.versionId
    }},
    "application/json"
)
---
{
    AccountId: vars.accountId,
    ApplicationType: applicationType,
    AmountPaid: amountPaid,
    Status: status,
    // Placeholder — see dev-questions.md for what this should actually be
    AppliedDate: |1900-01-01T12:00:00Z|,
    Category: "License",
    // Placeholder — see dev-questions.md for what Trade__c should be for Petroleum
    Trade__c: "TBD",
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy License Number: " ++ licenseno,
    Omni_JSON_Data__c: omniJsonData,
    Policy_Expiration_Date__c: insExpireDateParsed,
    PrimaryOwnerId: vars.contactId,
    SiteStreet: mailingStreet,
    SiteCity: vars.row.city default "",
    SiteStateCode: vars.row.state default "",
    SitePostalCode: padZip(vars.row.zip),
    SiteCountryCode: "US",
    OwnerId: vars.ownerId
}
