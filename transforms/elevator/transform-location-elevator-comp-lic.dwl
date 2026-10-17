%dw 2.0
import poBoxOnly from usermodules::Utils
output application/java

// Address comes from the matched company row (vars.company), not comp_lic — see flow-designs.md
// section 14, "Location / Address__c / PartyAddress__c"
var coLicenseNo = vars.row.co_license_no default ""

fun location(name: String) =
    {
        LocationType: "Business Site",
        Name: name,
        Description: if (name == "Mailing") "Elevator Mailing Address for Company License " ++ coLicenseNo
                     else "Company License Physical Location Address for Company License " ++ coLicenseNo,
        OwnerId: vars.ownerId
    }
---
[
    location("Mailing"),
    if (not poBoxOnly(vars.company.add1, vars.company.add2)) location("Physical Location") else null
] filter (l) -> l != null
