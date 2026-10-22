%dw 2.0
output application/java

// One InvoiceLine__c per Invoice__c, same hardcoded Quantity/LineType/ProrateFactor as Jewelry/Petroleum.
// UnitPrice = amt_billed from the payment.csv row (user, 2026-10-22); blank -> 0, same as Petroleum.
// Notes = location (user, 2026-10-22); API name Notes__c assumed, same as on Payment__c.
---
{
    Invoice__c: vars.invoiceId,
    Quantity__c: 1,
    LineType__c: "Base Fee",
    ProrateFactor__c: 100,
    UnitPrice__c: if ((vars.paymentRow.amt_billed default "") != "") vars.paymentRow.amt_billed as Number else 0,
    Notes__c: vars.paymentRow.location
    // OwnerId left out: the field doesn't exist on InvoiceLine__c (user, 2026-10-22)
}
