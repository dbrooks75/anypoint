%dw 2.0
output application/java

var namedRows = payload map (row) -> row ++ {
    RID: (row.RID default "" splitBy ".")[0]
}

var afterHardSkip = namedRows filter (row) -> not (["550", "551"] contains row.RID)

var dateRecdMissing = afterHardSkip filter (row) -> (row.DateRecd default "") == ""
var keptRows = afterHardSkip filter (row) -> (row.DateRecd default "") != ""

var skipLogEntries = dateRecdMissing map (row) -> {
    RID: row.RID,
    object: "Account",
    status: "Skipped",
    salesforce_id: null,
    error_code: null,
    error_message: "DateRecd missing - record not imported"
}

var feinNoteLogEntries = (keptRows filter (row) -> (row.CompanyFEIN default "") == "") map (row) -> {
    RID: row.RID,
    object: "Account",
    status: "Note",
    salesforce_id: null,
    error_code: null,
    error_message: "CompanyFEIN missing"
}
---
{
    rows: keptRows,
    logEntries: skipLogEntries ++ feinNoteLogEntries
}
