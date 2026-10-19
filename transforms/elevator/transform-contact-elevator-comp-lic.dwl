%dw 2.0
import parseName, cleanEmail from usermodules::Utils
output application/java

// Contact comes from the matched company row (vars.company): respparty is the person's name,
// written FIRST LAST. Only called when respparty is non-blank (see AddContactElevatorCompLic).
var parsed = parseName(vars.company.respparty)
---
{
    FirstName: parsed.firstName,
    MiddleName: parsed.middleName,
    LastName: parsed.lastName,
    AccountId: vars.accountId,
    Title: "Elevator Service",
    // TitleType left out: Salesforce returns an invalid-field error (field permissions open question)
    Phone: vars.company.phone,
    Fax: vars.company.fax,
    Email: cleanEmail(vars.company.email),
    OwnerId: vars.ownerId
}
