%dw 2.0
output application/java

var jobno = vars.row.jobno default ""

// SiteAddress = the Mailing address, same PO-Box-detection logic as transform-address.dwl's
// isMailing branch (Jewelry shares the same add1/add2/city/state/zip fields as Petroleum)
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
    Description: "Legacy Job Number: " ++ jobno,
    PrimaryOwnerId: vars.contactId,
    SiteStreet: mailingStreet,
    SiteCity: vars.row.city default "",
    SiteStateCode: vars.row.state default "",
    SitePostalCode: vars.row.zip default "",
    SiteCountryCode: "US"
}
