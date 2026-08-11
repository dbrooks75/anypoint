# Dev Team Questions

1. Will things like LicenseType be loaded before I do the conversion?
2. Note: AppliedDate is required on BusinessLicenseApplication.
3. ~~Does the integration user's profile have Edit access to Legacy_License_Number__c on BusinessLicense?~~ Confirmed working — field mapped in transform-business-license.dwl.
4. AssessmentQuestionVersion: please verify/fix the spelling of "Busness Hours" — should it be "Business Hours"?
5. Job 1996350007 has multiple deposits on the same day — 4 deposits total. Does the "1 invoice per AR line" rule still hold here, or should same-day deposits for the same job be consolidated into one invoice?
6. There are duplicate jobno values within his_labor_std. How should these be handled?
7. AssessmentQuestionResponse.ResponseType throws INVALID_FIELD_FOR_INSERT_UPDATE — seems to be set by a trigger. What are the rules for how it gets set, and do we need to do anything on our end (e.g. pre-populate AssessmentQuestionVersion) for it to come out right?
8. BusinessLicenseApplication.AppliedDate is required but we don't have a real source value for it (previously derived from issue_date, which isn't the right field). Currently hardcoded to a 1/1/1900 placeholder in transform-bla.dwl — what should this actually be?
9. ~~Petroleum: what should BusinessLicenseApplication.Trade__c be?~~ Resolved (2026-08-11) — hardcoded to "Petroleum" in transform-bla-petroleum.dwl. (Note: Jewelry's own Trade__c was separately updated 2026-08-04 to "Industrial Homework (Jewelry Shop) Permit", not "Labor Standards" as this question originally said — see flow-designs.md section 2.)
10. Petroleum: what is the real source/value for each vehicle's `registrationExpiry` in the PET_Delivery_Vehicles JSON? Currently hardcoded to a `"2026-04-09"` placeholder in transform-vehicles-petroleum.dwl (same treatment as the AppliedDate placeholder in #8).
11. ~~Petroleum: what should BusinessLicenseApplication.ApplicationType (New/Renewal) be based on?~~ Resolved (2026-07-17, supersedes the original 2026-07-15 "hardcoded New" answer) — "Renewal" if any of that licenseno's MercAR rows exist (matchingArRows), else "New". See transform-bla-petroleum.dwl and flow-designs.md section 6.
12. ~~Does the integration user's profile have Edit access to Payment__c.Notes__c?~~ Confirmed working — same class of issue as #3 (missing FLS), granted Edit access.
