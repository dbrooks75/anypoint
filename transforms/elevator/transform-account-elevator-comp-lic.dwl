%dw 2.0
import padZip from usermodules::Utils
output application/java

// Name, Phone and the Billing address come from the matched company row (vars.company, set by
// ElevatorMatchCompanyCompLic, which now runs before this transform), not comp_lic (user, 2026-10-22).
// No single company match: Name falls back to comp_lic.name (Account Name is required), the rest are null.
var c = vars.company
var hasCompany = c != null
---
{
    RecordTypeId: vars.accountRecordTypeId,
    Name: if (hasCompany and (c.name default "") != "") c.name else vars.row.name,
    BillingStreet: if (hasCompany) (c.add1 default "") ++
                   (if ((c.add2 default "") != "") " " ++ (c.add2 default "") else "") else null,
    BillingCity: if (hasCompany) c.city else null,
    BillingStateCode: if (hasCompany) upper(c.state default "") else null,
    BillingPostalCode: if (hasCompany) padZip(c.zip) else null,
    Phone: if (hasCompany) c.phone else null,
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1.1 - Conversion",
    OwnerId: vars.ownerId
}
