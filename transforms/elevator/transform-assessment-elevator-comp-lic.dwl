%dw 2.0
import parseDate, noonUtc from usermodules::Utils
output application/java
---
{
    AccountId: vars.accountId,
    BusinessLicenseApplication__c: vars.blaId,
    AssessmentStatus: "Completed",
    Name: "Universal License Assessment",
    Type: "LicensingAndPermitting",
    // comp_lic.date_first_issued (M/d/yyyy), noon UTC; blank -> null
    EffectiveDateTime: noonUtc(parseDate(vars.row.date_first_issued)),
    OwnerId: vars.ownerId
}
