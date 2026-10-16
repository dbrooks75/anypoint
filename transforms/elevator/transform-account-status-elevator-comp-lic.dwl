%dw 2.0
output application/java
---
{
    Account__c: vars.accountId,
    Effective_Date__c: if ((vars.row.date_first_issued default "") != "") vars.row.date_first_issued as Date {format: "M/d/yyyy"} else null,
    Status__c: "Active",
    OwnerId: vars.ownerId
}
