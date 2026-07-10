%dw 2.0
output application/java

var aqvList = vars.aqvMap
var insuranceCompany = vars.row.insurance_company default ""
var policyExpiration = vars.row.ins_expire_date default ""
var dateAppReceived = vars.row.date_issued default ""

var questions = [
    { name: "PET Name on Vehicle Different", responseType: "Checkbox",  choiceValue: false, dateValue: null, responseText: null },
    { name: "PET Name on Vehicle",           responseType: "Text",      choiceValue: null,  dateValue: null, responseText: null },
    { name: "PET Insurance Company",         responseType: "Text",      choiceValue: null,  dateValue: null, responseText: if (insuranceCompany != "") insuranceCompany else null },
    // Date format assumed to match LaborAR.csv's M/d/yyyy (non-padded) — unconfirmed for MercStd, see flow-designs.md section 6
    { name: "PET Policy Expiration",         responseType: "Date",      choiceValue: null,  dateValue: if (policyExpiration != "") policyExpiration as Date {format: "M/d/yyyy"} else null, responseText: null },
    { name: "PET Date App Received",         responseType: "Date",      choiceValue: null,  dateValue: if (dateAppReceived != "") dateAppReceived as Date {format: "M/d/yyyy"} else null, responseText: null },
    // vars.deliveryVehiclesJson comes from a prior Transform Message (transform-vehicles-petroleum.dwl), already a JSON string
    { name: "PET_Delivery_Vehicles",         responseType: "Text Area", choiceValue: null,  dateValue: null, responseText: vars.deliveryVehiclesJson }
]
---
questions map (q) -> do {
    var aqv = aqvList[q.name]
    ---
    {
        AssessmentId: vars.assessmentId,
        AssessmentQuestionId: aqv.Id,
        Name: aqv.QuestionText,
        CurrencyValue: null,
        DateValue: q.dateValue,
        IntegerResponseValue: null,
        ChoiceValue: if (q.choiceValue != null) q.choiceValue as String else null,
        ResponseText: q.responseText
    }
}
