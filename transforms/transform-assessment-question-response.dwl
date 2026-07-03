%dw 2.0
output application/java

var aqvList = vars.aqvMap
var questions = [
    {name: "Date App Received",          responseType: "Date"},
    {name: "Homework-Names-Address",     responseType: "Text Area"},
    {name: "Homework",                   responseType: "Text Area"},
    {name: "Type of Contract Work",      responseType: "Text Area"},
    {name: "Operated Address",           responseType: "Text Area"},
    {name: "Operated at Another Address",responseType: "Text Area"},
    {name: "Busness Hours",              responseType: "Text Area"}
]
---
questions map (q) -> do {
    var aqv = aqvList[q.name]
    ---
    {
        AssessmentId: vars.assessmentId,
        AssessmentQuestionId: aqv.Id,
        Name: aqv.QuestionText,
        ResponseType: q.responseType,
        CurrencyValue: null,
        DateValue: null,
        IntegerResponseValue: null,
        ChoiceValue: null,
        ResponseText: null
    }
}
