%dw 2.0
output application/java

// Assessment Question Responses for the Elevator Service Company application. One AQR per question,
// all linked to vars.assessmentId. The answers come from vars.aqrQuestions
// (transform-aqr-questions-elevator-comp-lic.dwl), shared with the BLA's Omni_JSON_Data__c.
---
vars.aqrQuestions map (q) -> {
    AssessmentId: vars.assessmentId,
    AssessmentQuestionId: q.versionId,
    Name: q.questionText,
    DateValue: q.dateValue,
    ResponseText: q.responseText,
    OwnerId: vars.ownerId
}
