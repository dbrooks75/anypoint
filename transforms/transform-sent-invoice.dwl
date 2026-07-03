%dw 2.0
output application/java
---
{
    Account__c: vars.accountId,
    BusinessLicenseApplication__c: vars.blaId,
    DueDate__c: |2026-09-30|,
    InvoiceDate__c: |2026-08-01|,
    InvoiceStatus__c: "Sent"
}
