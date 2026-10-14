%dw 2.0
output application/java

// Only Current-sourced BLAs, and only if that jobno has NO 2026 deposit_date in LaborAR
// (mirrors transform-bla.dwl's Status rule: if a 2026 deposit already exists, no cutover
// "Sent" invoice is needed for that account)
fun hasCurrentYearDeposit(jobno: String) =
    sizeOf(vars.laborArRows filter (row) ->
        (row.jobno default "") == jobno and
        (row.deposit_date default "") != "" and
        ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"
    ) > 0
---
vars.blaJobnoLog filter (entry) ->
    (entry.sourceFileType == "Current") and (not hasCurrentYearDeposit(entry.jobno))
