%dw 2.0
output application/java

// Only Current-sourced BLAs, and only if that licenseno has NO 2026 deposit_date in MercAR
// (mirrors transform-bla-petroleum.dwl's Status rule: if a 2026 deposit already exists, no
// cutover "Sent" invoice is needed for that account)
fun hasCurrentYearDeposit(licenseno: String) =
    sizeOf(vars.mercArRows filter (row) ->
        (row.licenseno default "") == licenseno and
        (row.deposit_date default "") != "" and
        ((row.deposit_date as Date {format: "M/d/yyyy"}) as String {format: "yyyy"}) == "2026"
    ) > 0
---
vars.blaLicenseLog filter (entry) ->
    (entry.sourceFileType == "Current") and not hasCurrentYearDeposit(entry.licenseno)
