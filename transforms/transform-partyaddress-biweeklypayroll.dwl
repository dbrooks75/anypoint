%dw 2.0
output application/java
---
{
    PartyId: vars.accountId,
    AddressId__c: vars.addressId,
    Effective_From__c: if ((vars.row.DateRecd default "") != "")
        ((vars.row.DateRecd as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null,
    Address_Type__c: vars.addressType,
    Is_Primary__c: vars.locationName == "Company"
}
