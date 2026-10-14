%dw 2.0
output application/java

// Question list + aqvMap lookup, plus the payment-method/day/salary normalization helpers, now
// live in transform-aqr-questions-biweeklypayroll.dwl (vars.aqrQuestions, set before
// AddBusinessLicenseAppBiWeeklyPayroll) — shared with transform-bla-biweeklypayroll.dwl's
// Omni_JSON_Data__c, so this just maps the already-resolved answers to AQR create records.
---
vars.aqrQuestions map (q) -> {
    AssessmentId: vars.assessmentId,
    AssessmentQuestionId: q.versionId,
    Name: q.questionText,
    CurrencyValue: null,
    DateValue: q.dateValue,
    IntegerResponseValue: q.integerValue,
    ChoiceValue: q.choiceValue,
    ResponseText: q.responseText,
    OwnerId: vars.ownerId
}
