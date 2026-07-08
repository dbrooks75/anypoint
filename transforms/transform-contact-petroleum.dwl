%dw 2.0
output application/java

var fname = vars.row.contact_fname default ""
var lname = vars.row.contact_lname default ""
---
if (fname != "" or lname != "")
    [
        {
            FirstName: vars.row.contact_fname,
            MiddleName: vars.row.contact_mi,
            LastName: vars.row.contact_lname,
            AccountId: vars.accountId,
            Title: "Petroleum",
            Email: vars.row.email_addr,
            // Format assumption — see flow-designs.md, not yet confirmed
            Phone: (vars.row.contact_area_code default "") ++ "-" ++ (vars.row.contact_telephone default "")
        }
    ]
else
    []
