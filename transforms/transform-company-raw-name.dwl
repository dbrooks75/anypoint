%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Reused for all three of Elevators' company source files: company.unl (Current),
// hi_company.unl (Historical), hi_company_pr.unl (Private) — confirmed 2026-08-24 all three
// share this same 14-column layout. vars.sourceFileType must be set to "Current"/"Historical"/
// "Private" before each call, same pattern as transform-laborstd-raw-name.dwl.
var allCols = [
    "recnumb", "predacc", "acc", "name", "respparty", "add1", "add2", "city", "state", "zip",
    "batchid", "phone", "fax", "email"
]
---
payload map (row) -> do {
    // trim every field before mapping to column names, same defensive default established for
    // the truck imports (transform-trucks-raw-name.dwl, 2026-08-17)
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
