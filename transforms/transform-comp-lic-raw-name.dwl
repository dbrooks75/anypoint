%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Reused for both of Elevators' comp_lic source files: comp_lic.unl (Current),
// hi_comp_lic.unl (Historical). vars.sourceFileType must be set to "Current"/"Historical"
// before each call, same pattern as transform-laborstd-raw-name.dwl. Note: comp_lic has no
// "recnum" field (unlike license, which has both recnum and recnumb) — confirmed 2026-08-24.
var allCols = [
    "license_category", "license_type", "license_ai", "co_license_no", "expire_date", "recnumb",
    "name", "add1", "add2", "city", "state", "zip",
    "date_first_issued", "fee", "invoice_no", "date_paid", "next_page", "warning_date_1",
    "reason_1", "warning_date_2", "reason_2", "warning_date_3", "reason_3", "suspend_date",
    "reason_suspend", "phone", "status", "date_entered", "comment", "batchid"
]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
