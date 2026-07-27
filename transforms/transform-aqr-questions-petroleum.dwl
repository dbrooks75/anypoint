%dw 2.0
output application/java

// Computed once per row, before AddBusinessLicenseAppPetroleum — feeds both
// transform-bla-petroleum.dwl's Omni_JSON_Data__c and
// transform-assessment-question-response-petroleum.dwl's AQR creation. See
// transform-aqr-questions.dwl (Jewelry) for why this is safe to compute ahead of BLA creation.

var aqvList = vars.aqvMap
var insuranceCompany = vars.row.insurance_company default ""
var policyExpiration = vars.row.ins_expire_date default ""
var dateAppReceived = vars.row.date_issued default ""

var questions = [
    { name: "PET Name on Vehicle Different", choiceValue: false, dateValue: null, integerValue: null, responseText: null },
    { name: "PET Name on Vehicle",           choiceValue: null,  dateValue: null, integerValue: null, responseText: null },
    { name: "PET Insurance Company",         choiceValue: null,  dateValue: null, integerValue: null, responseText: if (insuranceCompany != "") insuranceCompany else null },
    // Date format assumed to match LaborAR.csv's M/d/yyyy (non-padded) — unconfirmed for MercStd, see flow-designs.md section 6
    { name: "PET Policy Expiration",         choiceValue: null,  dateValue: if (policyExpiration != "") policyExpiration as Date {format: "M/d/yyyy"} else null, integerValue: null, responseText: null },
    { name: "PET Date App Received",         choiceValue: null,  dateValue: if (dateAppReceived != "") dateAppReceived as Date {format: "M/d/yyyy"} else null, integerValue: null, responseText: null },
    // vars.deliveryVehiclesJson comes from a prior Transform Message (transform-vehicles-petroleum.dwl), already a JSON string
    { name: "PET_Delivery_Vehicles",         choiceValue: null,  dateValue: null, integerValue: null, responseText: vars.deliveryVehiclesJson }
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
