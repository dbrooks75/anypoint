%dw 2.0
import parseDate, stripDecimal from usermodules::Utils
output application/java

// One Payment__c per Invoice__c, from the same payment.csv row (vars.paymentRow). Draft mapping, to confirm.

var p = vars.paymentRow
fun filled(v) = (v default "") != ""

// Payment method from whichever reference column is filled in (draft, first match wins);
// reference numbers are numeric Access columns, so strip any ".0" export artifact
var paymentMethod =
    if (filled(p.check_no)) "Check"
    else if (filled(p.moneyord_no)) "Money Order"
    else if (filled(p.cashrecpt_no)) "Cash"
    else if (filled(p.credit_card)) "Credit Card"
    else null

// payrecdate, blank -> 1/1/1900 (same default as the invoice sort, user 2026-10-21)
var payRecDate = parseDate(p.payrecdate) default |1900-01-01|

// Notes__c: one "Label: value" line per field (user, 2026-10-22); a blank value leaves the label with nothing after it
var notes = [
    "Location: " ++ (p.location default ""),
    "Deposit Voucher: " ++ (p.deposit_voucher default ""),
    "Deposit Date: " ++ (p.deposit_date default ""),
    "Delinquent: " ++ (p.delinquent default ""),
    "Printed Date: " ++ (p.ltr_printed_date default "")
] joinBy "\n"

var referenceNumber =
    if (filled(p.check_no)) stripDecimal(p.check_no)
    else if (filled(p.moneyord_no)) stripDecimal(p.moneyord_no)
    else if (filled(p.cashrecpt_no)) stripDecimal(p.cashrecpt_no)
    else null
---
{
    BusinessLicenseApplication__c: vars.blaId,
    Invoice__c: vars.invoiceId,
    Amount__c: if (filled(p.amtreceived)) p.amtreceived as Number else 0,
    PaymentDate__c: payRecDate,
    ReceiptDate__c: payRecDate,   // user, 2026-10-22
    Payment_Method__c: paymentMethod,
    // bill_or_pay: P (billed and paid) -> Completed; B (billed, not paid) or anything else -> Pending (user, 2026-10-22)
    Payment_Status__c: if ((p.bill_or_pay default "") == "P") "Completed" else "Pending",
    ReferenceNumber__c: referenceNumber
    // Notes__c: notes,   commented out (user, 2026-10-22): the create fails with it, open question
    // OwnerId left out: the field doesn't exist on Payment__c in dp04 (user, 2026-10-22)
}
