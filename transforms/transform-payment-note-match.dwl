%dw 2.0
output application/java

// Determines which raw LaborAR.csv column holds this payment's reference number, based on
// Payment_Method__c (same pymt_type discriminator as transform-payment.dwl), then looks for
// exactly one AR row (within the already jobno-scoped vars.matchingArRows) whose reference
// number and deposit_date match this payment. Returns matchCount so the caller can log whether
// a miss was "not found" (0) vs "ambiguous" (>1), not just null either way.
var refField =
    if (vars.payment.Payment_Method__c == "Check") "check_no"
    else if (vars.payment.Payment_Method__c == "Cash") "cash_recpt_no"
    else if (vars.payment.Payment_Method__c == "Money Order") "mo_ord_no"
    else null

fun stripDecimal(v) = (v default "" splitBy ".")[0]

// PaymentDate__c comes back from the Salesforce connector as a Date already (per the connector's
// field metadata) — coerced here defensively in case it arrives as an ISO string instead;
// not yet verified against a real query response in Studio.
var matches = if (refField == null) []
    else vars.matchingArRows filter (row) ->
        (stripDecimal(row[refField]) == (vars.payment.ReferenceNumber__c default "")) and
        ((row.deposit_date default "") != "" and
            (row.deposit_date as Date {format: "M/d/yyyy"}) == (vars.payment.PaymentDate__c as Date))
---
{
    matchCount: sizeOf(matches),
    matchedRow: if (sizeOf(matches) == 1) matches[0] else null
}
