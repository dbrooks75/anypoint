%dw 2.0
output application/java
---
{
    PartyId: vars.accountId,
    AddressId__c: vars.addressId,
    Effective_From__c: if ((vars.row.issue_date default "") != "")
        ((vars.row.issue_date as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null,
    Address_Type__c: vars.addressType,
    Is_Primary__c: vars.addressType == "Mailing"
}
