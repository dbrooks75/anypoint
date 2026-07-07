# Dev Team Questions

1. Will things like LicenseType be loaded before I do the conversion?
2. Note: AppliedDate is required on BusinessLicenseApplication.
3. ~~Does the integration user's profile have Edit access to Legacy_License_Number__c on BusinessLicense?~~ Confirmed working — field mapped in transform-business-license.dwl.
4. AssessmentQuestionVersion: please verify/fix the spelling of "Busness Hours" — should it be "Business Hours"?
5. Job 1996350007 has multiple deposits on the same day — 4 deposits total. Does the "1 invoice per AR line" rule still hold here, or should same-day deposits for the same job be consolidated into one invoice?
6. There are duplicate jobno values within his_labor_std. How should these be handled?
7. AssessmentQuestionResponse.ResponseType throws INVALID_FIELD_FOR_INSERT_UPDATE — seems to be set by a trigger. What are the rules for how it gets set, and do we need to do anything on our end (e.g. pre-populate AssessmentQuestionVersion) for it to come out right?
8. BusinessLicenseApplication.AppliedDate is required but we don't have a real source value for it (previously derived from issue_date, which isn't the right field). Currently hardcoded to a 1/1/1900 placeholder in transform-bla.dwl — what should this actually be?
