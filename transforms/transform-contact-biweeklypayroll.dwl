%dw 2.0
output application/java

fun parseName(raw: String) = do {
    var words = (trim(raw) splitBy " ") filter (w) -> w != ""
    var count = sizeOf(words)
    ---
    {
        firstName: words[0] default "",
        middleName: if (count >= 3) (words[1 to count - 2] joinBy " ") else null,
        lastName: if (count >= 2) words[-1] else null
    }
}

fun cleanEmail(email: String) =
    if (email matches /^[^\s@]+@[^\s@]+\.[^\s@]+$/) email else ""

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

var companyContact = vars.row.CompanyContact default ""
var parsedCompanyName = parseName(companyContact)
var companyPhone = vars.row.CompanyTel default ""

var riAgentName = vars.row.RIagentName default ""
var riAgentPhone = vars.row.RIagentTel default ""
---
[
    if (companyContact != "")
        {
            FirstName: parsedCompanyName.firstName,
            MiddleName: parsedCompanyName.middleName,
            LastName: parsedCompanyName.lastName,
            Email: cleanEmail(vars.row.Email default ""),
            Title: vars.row.CompanyContactTitle,
            AccountId: vars.accountId,
            Phone: companyPhone,
            OwnerId: vars.ownerId
        }
    else null,
    if (riAgentName != "")
        {
            LastName: riAgentName,
            Title: "RI Agent",
            AccountId: vars.accountId,
            Phone: riAgentPhone,
            MailingStreet: vars.row.RIagentAddr,
            MailingCity: vars.row.RIagentCity,
            MailingStateCode: vars.row.RIagentState,
            MailingPostalCode: padZip(vars.row.RIagentZip),
            MailingCountryCode: "US",
            OwnerId: vars.ownerId
        }
    else null
] filter (c) -> c != null
