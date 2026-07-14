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

var companyContact = vars.row.CompanyContact default ""
var parsedCompanyName = parseName(companyContact)

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
            AccountId: vars.accountId
        }
    else null,
    if (riAgentName != "")
        {
            LastName: riAgentName,
            Title: "RI Agent",
            AccountId: vars.accountId,
            Phone: if (riAgentPhone != "") riAgentPhone else "(999) 999-9999"
        }
    else null
] filter (c) -> c != null
