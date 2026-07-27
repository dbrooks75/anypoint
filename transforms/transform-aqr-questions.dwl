%dw 2.0
output application/java

// Computed once per row, before AddBusinessLicenseApp — feeds both transform-bla.dwl's
// Omni_JSON_Data__c and transform-assessment-question-response.dwl's AQR creation, so the
// per-question answer logic only lives in one place. Doesn't depend on assessmentId/blaId,
// only vars.row and vars.aqvMap (already populated by InitAssessmentQuestionVersion, once
// upfront), so it's safe to compute ahead of BLA/BusinessLicense/Assessment creation.

var aqvList = vars.aqvMap

// No source-column mapping confirmed yet for any of these 7 questions (see dev-questions.md) —
// all-null placeholder, same as the current transform-assessment-question-response.dwl.
var questions = [
    { name: "Date App Received",           dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Homework-Names-Address",      dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Homework",                    dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Type of Contract Work",       dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Operated Address",            dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Operated at Another Address", dateValue: null, integerValue: null, choiceValue: null, responseText: null },
    { name: "Busness Hours",               dateValue: null, integerValue: null, choiceValue: null, responseText: null }
]

fun resolveValue(q) =
    if (q.dateValue != null) q.dateValue
    else if (q.integerValue != null) q.integerValue
    else if (q.choiceValue != null) q.choiceValue
    else if (q.responseText != null) q.responseText
    else null
---
questions map ((q, idx) -> do {
    var aqv = aqvList[q.name]
    ---
    {
        name: q.name,
        answeredIndex: idx,
        category: "General",
        questionText: aqv.QuestionText,
        versionId: aqv.Id,
        dataType: aqv.DataType,
        value: resolveValue(q),
        dateValue: q.dateValue,
        integerValue: q.integerValue,
        choiceValue: q.choiceValue,
        responseText: q.responseText
    }
})
