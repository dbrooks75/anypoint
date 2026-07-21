%dw 2.0
output application/java
---
{
    Account__c: vars.accountId,
    Effective_Date__c: if ((vars.row.DateRecd default "") != "") vars.row.DateRecd as Date {format: "M/d/yyyy"} else null,
    Status__c: "Active"
}
