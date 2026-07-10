%dw 2.0
output application/java

var pymtType = vars.row.pymt_type default ""

var paymentMethod =
    if (pymtType == "K") "Check"
    else if (pymtType == "C") "Cash"
    else if (pymtType == "M") "Money Order"
    else null

var referenceNumber =
    if (pymtType == "K") (vars.row.check_no default "" splitBy ".")[0]
    else if (pymtType == "C") (vars.row.cash_recpt_no default "" splitBy ".")[0]
    else if (pymtType == "M") (vars.row.mo_ord_no default "" splitBy ".")[0]
    else null

var paymentDate =
    if ((vars.row.deposit_date default "") != "")
        vars.row.deposit_date as Date {format: "M/d/yyyy"}
    else null
---
{
    BusinessLicenseApplication__c: vars.blaId,
    Invoice__c: vars.invoiceId,
    Amount__c: if ((vars.row.pymt_amt default "") != "") vars.row.pymt_amt as Number else null,
    PaymentDate__c: paymentDate,
    Payment_Method__c: paymentMethod,
    Payment_Status__c: "Completed",
    ReceiptDate__c: paymentDate,
    ReferenceNumber__c: referenceNumber
}
