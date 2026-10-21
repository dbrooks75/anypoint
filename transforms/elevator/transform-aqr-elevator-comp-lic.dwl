%dw 2.0
import parseDate from usermodules::Utils
output application/java

// Assessment Question Responses for the Elevator Service Company application. One AQR per question,
// all linked to vars.assessmentId; questions resolved through vars.aqvMap
// (transform-aqv-lookup-elevator.dwl). Every answer is empty for now except Date App Received.
//
// Date App Received: two separate questions share that Name, so pick by the BLA's ApplicationType
// (vars.blaApplicationType): New -> ESC_Date_App_Received, Renewal -> ESC_Date_Renewal_App_Received.
var dateQuestionKey = if ((vars.blaApplicationType default "") == "Renewal")
        "ESC_Date_Renewal_App_Received"
    else "ESC_Date_App_Received"

var questions = [
    { key: "ESC Equipment Types",        dateValue: null, responseText: null },   // Multiselect
    { key: "ESC Equipment Type Other",   dateValue: null, responseText: null },   // Text (open: needed? source?)
    { key: "ESC Other RI Licenses Held", dateValue: null, responseText: null },   // TextArea
    { key: "ESC Employee License",       dateValue: null, responseText: null },   // TextArea
    { key: "ESC Owner Experience",       dateValue: null, responseText: null },   // TextArea
    { key: dateQuestionKey,              dateValue: parseDate(vars.row.date_first_issued), responseText: null }  // Date
]
---
questions map (q) -> do {
    var aqv = vars.aqvMap[q.key]
    ---
    {
        AssessmentId: vars.assessmentId,
        AssessmentQuestionId: aqv.Id,
        Name: aqv.QuestionText,
        DateValue: q.dateValue,
        ResponseText: q.responseText,
        OwnerId: vars.ownerId
    }
}
