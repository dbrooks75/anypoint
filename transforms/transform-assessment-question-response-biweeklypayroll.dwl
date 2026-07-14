%dw 2.0
output application/java

var aqvList = vars.aqvMap

fun normalizePaymentMethods(raw) = do {
    var inputStr = raw default ""
    var lowerStr = lower(inputStr)
    ---
    if (inputStr == "") ""
    else do {
        var parts = [
            if (lowerStr contains "check") "Check" else null,
            if (lowerStr contains "direct deposit") "Direct Deposit" else null,
            if (lowerStr contains "pay card" or lowerStr contains "paycard") "Pay Card" else null,
            if (lowerStr contains "other") "Other" else null
        ] filter (p) -> p != null
        ---
        if (isEmpty(parts)) "Other" else (parts joinBy "; ")
    }
}

fun normalizeDayValue(raw) = do {
    var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    var normalizedInput = lower(trim(raw default ""))
    var matches = days filter (day) -> (normalizedInput contains lower(day)) or (normalizedInput contains (lower(day) ++ "s"))
    ---
    if (isEmpty(matches)) "" else matches[0]
}

fun safeVal(s) = do {
    var trimmed = trim(s default "")
    var m = trimmed scan /^-?[0-9]+(?:\.[0-9]+)?/
    ---
    if (isEmpty(m)) 0 else (m[0][0] as Number)
}

fun convertToBiweekly(value, payType) =
    if (payType == "hourly") value * 80
    else if (payType == "biweekly") value
    else if (payType == "annual") value / 26
    else 0

fun getBiweeklySalary(rangeStr, selector) = do {
    var sel = lower(selector default "")
    var raw = rangeStr default ""
    ---
    if (trim(raw) == "" or (sel != "min" and sel != "max")) 0
    else do {
        var c1 = lower(raw)
        var c2 = c1 replace "$" with ""
        var c3 = c2 replace "," with ""
        var c4 = c3 replace "+" with ""
        var c5 = c4 replace " to " with "-"
        var c6 = c5 replace "to" with "-"

        var detectedPayType =
            if (c6 contains "hour") "hourly"
            else if (c6 contains "week" or c6 contains "biweekly") "biweekly"
            else if (c6 contains "year" or c6 contains "annual" or c6 contains "annually") "annual"
            else ""

        var d1 = c6 replace "per hour" with ""
        var d2 = d1 replace "/hour" with ""
        var d3 = d2 replace "hour" with ""
        var d4 = d3 replace "per week" with ""
        var d5 = d4 replace "/week" with ""
        var d6 = d5 replace "week" with ""
        var d7 = d6 replace "biweekly" with ""
        var d8 = d7 replace "per year" with ""
        var d9 = d8 replace "/year" with ""
        var d10 = d9 replace "/ annually" with ""
        var d11 = d10 replace "annually" with ""
        var d12 = d11 replace "annual" with ""
        var d13 = d12 replace "year" with ""
        var cleaned = d13 replace " " with ""
        ---
        if (cleaned == "") 0
        else do {
            var parts = cleaned splitBy "-"
            var minVal = safeVal(parts[0])
            var maxVal = if (sizeOf(parts) > 1) safeVal(parts[1]) else minVal
            ---
            if (minVal <= 0 or maxVal <= 0) 0
            else do {
                var resolvedPayType =
                    if (detectedPayType != "") detectedPayType
                    else if (maxVal <= 300) "hourly"
                    else if (maxVal <= 10000) "biweekly"
                    else "annual"
                var result = if (sel == "min") convertToBiweekly(minVal, resolvedPayType)
                             else convertToBiweekly(maxVal, resolvedPayType)
                ---
                round(result)
            }
        }
    }
}

var dateRecd = vars.row.DateRecd default ""

var questions = [
    { name: "Avg Payroll Exceed 200",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: if ((vars.row.PayrollRec200Chk default "") == "Yes") "Yes" else "No" },
    { name: "Company Payroll",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: if ((vars.row.PayrollRecChk default "") == "Yes") "Yes" else "No" },
    { name: "Estimated Wages",
      choiceValue: null, dateValue: null, integerValue: 0,
      responseText: null },
    { name: "Payment Method",
      choiceValue: normalizePaymentMethods(vars.row.MethodPaid), dateValue: null, integerValue: null,
      responseText: null },
    { name: "Payment Day",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: normalizeDayValue(vars.row.PayDay) },
    { name: "Employee Class",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: null },
    { name: "Salary Min",
      choiceValue: null, dateValue: null, integerValue: getBiweeklySalary(vars.row.SalaryRangeInvolved, "min"),
      responseText: null },
    { name: "Salary Max",
      choiceValue: null, dateValue: null, integerValue: getBiweeklySalary(vars.row.SalaryRangeInvolved, "max"),
      responseText: null },
    { name: "Bond Value",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: null },
    { name: "Bond Expiration Date",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: null },
    { name: "Pay Violation",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: if ((vars.row.WageHrViol default "") == "Yes") "Yes" else "No" },
    { name: "Collective Bargaining",
      choiceValue: null, dateValue: null, integerValue: null,
      responseText: if ((vars.row.ConsentColBargChk default "") == "Yes") "Yes" else "No" },
    { name: "Date Application Received",
      choiceValue: null, dateValue: if (dateRecd != "") dateRecd as Date {format: "M/d/yyyy"} else null, integerValue: null,
      responseText: null }
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
        IntegerResponseValue: q.integerValue,
        ChoiceValue: q.choiceValue,
        ResponseText: q.responseText
    }
}
