%dw 2.0
import parseDate, stripDecimal from usermodules::Utils
output application/java

// One Invoice__c per payment.csv row (vars.paymentRow, set inside the AddInvoicesElevatorCompLic For Each).
// Salesforce Date fields: leave as DataWeave Date, not a String (section 3).
var billOrPay = vars.paymentRow.bill_or_pay default ""
var invoiceStatus =
    if (billOrPay == "P") "Paid"
    else if (billOrPay == "" and (vars.paymentRow.deposit_date default "") != "") "Paid"
    else "Sent"
---
{
    Account__c: vars.accountId,
    BusinessLicenseApplication__c: vars.blaId,
    // DueDate = deposit_date, same as Jewelry/Petroleum (draft, to confirm)
    DueDate__c: parseDate(vars.paymentRow.deposit_date),
    InvoiceDate__c: parseDate(vars.paymentRow.invoice_date),
    // bill_or_pay P -> Paid; blank bill_or_pay with a deposit_date -> Paid; B or anything else -> Sent (user, 2026-10-22)
    InvoiceStatus__c: invoiceStatus,
    // invoice_no (user, 2026-10-22); decimal-stripped in case Access exported it as "12345.0"; blank -> null
    Legacy_Invoice_Number__c: if ((vars.paymentRow.invoice_no default "") != "") stripDecimal(vars.paymentRow.invoice_no) else null,
    OwnerId: vars.ownerId
}
