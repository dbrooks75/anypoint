%dw 2.0
import padZip from usermodules::Utils
output application/java
---
{
    RecordTypeId: vars.accountRecordTypeId,
    Name: vars.row.name,
    BillingStreet: (vars.row.add1 default "") ++
                   (if ((vars.row.add2 default "") != "") " " ++ (vars.row.add2 default "") else ""),
    BillingCity: vars.row.city,
    BillingStateCode: upper(vars.row.state default ""),
    BillingPostalCode: padZip(vars.row.zip),
    Phone: vars.row.phone,
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1.1 - Conversion",
    OwnerId: vars.ownerId
}
