%dw 2.0
output application/java

// Used only for comp_lic.unl (Current) — confirmed 2026-08-26 hi_comp_lic.unl (Historical) has
// a different 29-column layout (missing "license_ai"), so it now has its own dedicated
// transform, transform-comp-lic-historical-raw-name.dwl. Note: comp_lic has no "recnum" field
// (unlike license, which has both recnum and recnumb) — confirmed 2026-08-24.
// No input directive here (corrected 2026-08-25) -- the File Read component's own MIME
// Type tab (application/csv, quote=NUL, separator=|, header=false) parses the raw .unl
// before payload reaches this transform, matching ImportSourceDataPetroleum's pattern.
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
