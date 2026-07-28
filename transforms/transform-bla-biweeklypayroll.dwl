%dw 2.0
output application/java

var rid = vars.row.RID default ""

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

var dateRecd = (vars.row.DateRecd default "") != ""
var dateApproved = (vars.row.DateApproved default "") != ""
var dateDenied = (vars.row.DateDenied default "") != ""
var dateExpired = (vars.row.DateExpired default "") != ""
var dateRevoked = (vars.row.DateRevoked default "") != ""
var dateRenewed = (vars.row.DateRenewed default "") != ""

var status =
    if (dateRecd and !dateApproved and !dateDenied and !dateExpired and !dateRevoked and !dateRenewed) "Submitted"
    else if (dateRecd and !dateApproved and !dateExpired and dateDenied) "Denied"
    else "Approved"

var applicationType =
    if ((vars.row.TypAppl default "") == "Initial") "New"
    else if ((vars.row.TypAppl default "") == "Re-application") "Renewal"
    else "Initial"

// Omni_JSON_Data__c: AnswerList JSON built from vars.aqrQuestions (see
// transform-aqr-questions-biweeklypayroll.dwl), computed before this transform runs. MultiSelect
// answers (e.g. "Payment Method") are reshaped from the semicolon-joined string the AQR record
// needs into a real JSON array — unconfirmed delimiter assumption ("; "), matches
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
    AmountPaid: 0,
    Status: status,
    AppliedDate: if ((vars.row.DateRecd default "") != "")
        ((vars.row.DateRecd as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null,
    Category: "License",
    Trade__c: null,
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy RID: " ++ rid,
    Omni_JSON_Data__c: omniJsonData,
    PrimaryOwnerId: vars.contactId,
    SiteStreet: vars.row.CompanyAddr default "",
    SiteCity: vars.row.CompanyCity default "",
    SiteStateCode: vars.row.CompanyState default "",
    SitePostalCode: padZip(vars.row.CompanyZip),
    SiteCountryCode: "US"
}
