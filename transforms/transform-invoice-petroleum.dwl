%dw 2.0
output application/java

var pymtType = vars.row.pymt_type default ""

var invoiceDateRaw =
    if (pymtType == "K") vars.row.check_date
    else if (pymtType == "C") vars.row.cash_pymt_date
    else if (pymtType == "M") vars.row.mo_ord_date
    else null

// Falls back to deposit_date if the pymt_type-driven date is blank
var invoiceDateSource =
    if ((invoiceDateRaw default "") != "") invoiceDateRaw else vars.row.deposit_date

var invoiceDate =
    if ((invoiceDateSource default "") != "")
        invoiceDateSource as Date {format: "M/d/yyyy"}
    else null

var dueDate =
    if ((vars.row.deposit_date default "") != "")
        vars.row.deposit_date as Date {format: "M/d/yyyy"}
    else null
---
{
    Account__c: vars.accountId,
    BusinessLicenseApplication__c: vars.blaId,
    DueDate__c: dueDate,
    InvoiceDate__c: invoiceDate,
    InvoiceStatus__c: "Paid"
}
