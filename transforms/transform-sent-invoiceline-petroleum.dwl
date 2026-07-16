%dw 2.0
output application/java
---
{
    Invoice__c: vars.sentInvoiceId,
    Quantity__c: 1,
    LineType__c: "Base Fee",
    ProrateFactor__c: 100,
    UnitPrice__c: 120
}
