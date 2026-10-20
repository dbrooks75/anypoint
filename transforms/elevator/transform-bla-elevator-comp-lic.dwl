%dw 2.0
import recnumbKey, streetFor, padZip, parseDate from usermodules::Utils
output application/java

var coLicenseNo = vars.row.co_license_no default ""
var hasCompany = vars.company != null

// This row's payments from payment.csv (vars.paymentsByKey, see transform-payment-lookup-elevator.dwl),
// matched on recnumb + SourceFileType. Every matched row counts as a payment for now (user, 2026-10-20;
// may be narrowed later, e.g. by bill_or_pay).
var payments = vars.paymentsByKey[recnumbKey(vars.row.recnumb, vars.row.SourceFileType)] default []

var hasPayment = sizeOf(payments) > 0

// Payments with a deposit_date, for the date-based rules (latest payment, 2026 check)
var datedPayments = payments filter (p) -> (p.deposit_date default "") != ""

var latestPayment = if (sizeOf(datedPayments) > 0)
        (datedPayments orderBy (p) -> parseDate(p.deposit_date))[-1]
    else null

var has2026Payment = sizeOf(datedPayments filter (p) ->
    (parseDate(p.deposit_date) as String {format: "yyyy"}) == "2026") > 0

// Historical -> Approved; Current -> Approved only with a 2026 payment, else Draft
var status =
    if ((vars.row.SourceFileType default "") == "Historical") "Approved"
    else if (has2026Payment) "Approved"
    else "Draft"

// PaymentDaterec (and Payment Received Date, once found): max deposit_date, null when Draft
var paymentDate = if (status == "Draft" or latestPayment == null) null else parseDate(latestPayment.deposit_date)
---
{
    AccountId: vars.accountId,
    Status: status,
    ApplicationType: if (hasPayment) "Renewal" else "New",
    ApplicationCategory: "Basic",
    Category: "License",
    // Placeholder (same as Petroleum): AppliedDate is required, real source still an open question
    AppliedDate: |1900-01-01T12:00:00Z|,
    // Approved Date: null, so left out (same result as setting it to null)
    LicenseTypeId: vars.licenseTypeId,
    Fee_Payment_Required__c: true,
    // 0 when Draft (same as Petroleum); otherwise amtreceived of the latest payment
    AmountPaid: if (status == "Draft") 0
                else if (latestPayment != null and (latestPayment.amtreceived default "") != "")
                    latestPayment.amtreceived as Number
                else null,
    PaymentDaterec: paymentDate,
    // Payment Received Date (same value as PaymentDaterec) left out: no such field found on the
    // BLA in Salesforce yet (open question)
    Trade__c: "Elevator",
    // LicensePermitNameId (lookup to the Business License) is set by an Update after the Business
    // License is created, same as Jewelry/Petroleum (section 12) — not at BLA create
    Description: "Legacy co_license_no: " ++ coLicenseNo,
    // Site address = the Mailing address, from the matched company row (same as the Mailing Address__c)
    // (all null when there was no single company match)
    SiteStreet: if (hasCompany) streetFor(vars.company.add1, vars.company.add2, "Mailing") else null,
    SiteCity: if (hasCompany) vars.company.city else null,
    SiteStateCode: if (hasCompany) upper(vars.company.state default "") else null,
    SitePostalCode: if (hasCompany) padZip(vars.company.zip) else null,
    SiteCountryCode: if (hasCompany) "US" else null,
    OwnerId: vars.ownerId
}
