%dw 2.0
output application/java

// Question list + aqvMap lookup now computed once in transform-aqr-questions.dwl
// (vars.aqrQuestions, set before AddBusinessLicenseApp) — shared with transform-bla.dwl's
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
