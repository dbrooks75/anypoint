%dw 2.0
import recnumbKey, parseDate from usermodules::Utils
output application/java

// The Elevator Service Company application's answers, computed once per row at the start of
// AddBLAElevatorCompLic (before the BLA transform) and stored as vars.aqrQuestions. Feeds both the
// BLA's Omni_JSON_Data__c (transform-bla-elevator-comp-lic.dwl) and the AQR creates
// (transform-aqr-elevator-comp-lic.dwl), same approach as the other work units (flow-designs.md section 10).
// Questions resolved through vars.aqvMap (transform-aqv-lookup-elevator.dwl). Every answer is empty
// for now except Date App Received.
//
// Date App Received: two separate questions share that Name, so pick by the BLA's ApplicationType:
// New -> ESC_Date_App_Received, Renewal -> ESC_Date_Renewal_App_Received. This runs before the BLA
// transform, so ApplicationType is worked out here with the BLA's own rule: Renewal when the row
// has any matched payment.csv rows, else New.
var hasPayment = sizeOf(vars.paymentsByKey[recnumbKey(vars.row.recnumb, vars.row.SourceFileType)] default []) > 0

var dateQuestionKey = if (hasPayment) "ESC_Date_Renewal_App_Received" else "ESC_Date_App_Received"

var questions = [
    { key: "ESC Equipment Types",        dateValue: null, responseText: null },   // Multiselect
    { key: "ESC Equipment Type Other",   dateValue: null, responseText: null },   // Text (open: needed? source?)
    { key: "ESC Other RI Licenses Held", dateValue: null, responseText: null },   // TextArea
    { key: "ESC Employee License",       dateValue: null, responseText: null },   // TextArea
    { key: "ESC Owner Experience",       dateValue: null, responseText: null },   // TextArea
    { key: dateQuestionKey,              dateValue: parseDate(vars.row.date_first_issued), responseText: null }  // Date
]
---
questions map ((q, idx) -> do {
    var aqv = vars.aqvMap[q.key]
    ---
    {
        answeredIndex: idx,
        category: "General",
        questionText: aqv.QuestionText,
        versionId: aqv.Id,
        dataType: aqv.DataType,
        value: if (q.dateValue != null) q.dateValue else q.responseText,
        dateValue: q.dateValue,
        responseText: q.responseText
    }
})
