%dw 2.0
output application/java
---
{
    Invoice__c: vars.invoiceId,
    Quantity__c: 1,
    LineType__c: "Base Fee",
    ProrateFactor__c: 100,
    UnitPrice__c: if ((vars.row.tot_pymt_amt default "") != "") vars.row.tot_pymt_amt as Number else 0
}
