%dw 2.0
output application/java

var rid = vars.row.RID default ""

var dateRecd = (vars.row.DateRecd default "") != ""
var dateApproved = (vars.row.DateApproved default "") != ""
var dateDenied = (vars.row.DateDenied default "") != ""
var dateExpired = (vars.row.DateExpired default "") != ""
var dateRevoked = (vars.row.DateRevoked default "") != ""
var dateRenewed = (vars.row.DateRenewed default "") != ""

var status =
    if (dateRecd and !dateApproved and !dateDenied and !dateExpired and !dateRevoked and !dateRenewed) "Submitted"
    else if (dateRecd and !dateApproved and !dateExpired and dateDenied) "Denied"
    else "Approved"

var applicationType =
    if ((vars.row.TypAppl default "") == "Initial") "New"
    else if ((vars.row.TypAppl default "") == "Re-application") "Renewal"
    else "Initial"
---
{
    AccountId: vars.accountId,
    ApplicationType: applicationType,
    AmountPaid: 0,
    Status: status,
    AppliedDate: if ((vars.row.DateRecd default "") != "")
        ((vars.row.DateRecd as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) ++ "T00:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}
    else null,
    Category: "License",
    Trade__c: null,
    LicenseTypeId: vars.licenseTypeId,
    Description: "Legacy RID: " ++ rid,
    PrimaryOwnerId: vars.contactId,
    SiteStreet: vars.row.CompanyAddr default "",
    SiteCity: vars.row.CompanyCity default "",
    SiteStateCode: vars.row.CompanyState default "",
    SitePostalCode: vars.row.CompanyZip default "",
    SiteCountryCode: "US"
}
