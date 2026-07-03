# Dev Team Questions

1. Will things like LicenseType be loaded before I do the conversion?
2. Note: AppliedDate is required on BusinessLicenseApplication.
3. ~~Does the integration user's profile have Edit access to Legacy_License_Number__c on BusinessLicense?~~ Confirmed working — field mapped in transform-business-license.dwl.
4. AssessmentQuestionVersion: please verify/fix the spelling of "Busness Hours" — should it be "Business Hours"?
5. Job 1996350007 has multiple deposits on the same day — 4 deposits total. Does the "1 invoice per AR line" rule still hold here, or should same-day deposits for the same job be consolidated into one invoice?
6. There are duplicate jobno values within his_labor_std. How should these be handled?
