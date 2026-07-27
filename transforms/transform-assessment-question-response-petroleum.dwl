%dw 2.0
output application/java

// Question list + aqvMap lookup now computed once in transform-aqr-questions-petroleum.dwl
// (vars.aqrQuestions, set before AddBusinessLicenseAppPetroleum) — shared with
// transform-bla-petroleum.dwl's Omni_JSON_Data__c, so this just maps the already-resolved
// answers to AQR create records. ChoiceValue still needs the `as String` cast here (Salesforce
// field is a String/picklist) even though vars.aqrQuestions keeps the raw boolean for the JSON.
---
vars.aqrQuestions map (q) -> {
    AssessmentId: vars.assessmentId,
    AssessmentQuestionId: q.versionId,
    Name: q.questionText,
    CurrencyValue: null,
    DateValue: q.dateValue,
    IntegerResponseValue: null,
    ChoiceValue: if (q.choiceValue != null) q.choiceValue as String else null,
    ResponseText: q.responseText
}
