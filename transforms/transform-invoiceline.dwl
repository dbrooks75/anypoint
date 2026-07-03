%dw 2.0
output application/java
---
{
    Invoice__c: vars.invoiceId,
    Quantity__c: 1,
    LineType__c: "Base Fee",
    ProrateFactor__c: 100,
    UnitPrice__c: if ((vars.row.pymt_code_amt default "") != "") vars.row.pymt_code_amt as Number else null
}
