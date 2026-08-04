%dw 2.0
output application/java

// AddressType determined here from vars.locationName (2026-08-04), same three-way mapping as
// transform-address-biweeklypayroll.dwl, rather than reading an externally-set vars.addressType
var addressType =
    if (vars.locationName == "Company") "Mailing"
    else if (vars.locationName == "Corporate") "Corporate"
    else "Physical"
---
{
    PartyId: vars.accountId,
    AddressId__c: vars.addressId,
    Effective_From__c: if ((vars.row.DateRecd default "") != "")
        ((vars.row.DateRecd as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null,
    Address_Type__c: addressType,
    Is_Primary__c: vars.locationName == "Company",
    OwnerId: vars.ownerId
}
