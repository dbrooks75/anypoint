%dw 2.0
output application/java

// Elevators' own "license" table (individual mechanic licenses) — reused for both source
// files: license.unl (Current), hi_license.unl (Historical). vars.sourceFileType must be set
// to "Current"/"Historical" before each call. Named transform-elevator-license-raw-name.dwl
// (not transform-license-raw-name.dwl) to avoid confusion with this project's existing
// "license" terminology (BusinessLicense/RegulatoryAuthorization, vars.licenseTypeId) on the
// Jewelry/Petroleum/BiWeeklyPayroll side — this is an unrelated Elevators-specific object.
// Note: this table has BOTH "recnum" and "recnumb" as separate columns (confirmed 2026-08-24)
// — unlike comp_lic, which only has recnumb.
// No input directive here (corrected 2026-08-25) -- the File Read component's own MIME
// Type tab (application/csv, quote=NUL, separator=|, header=false) parses the raw .unl
// before payload reaches this transform, matching ImportSourceDataPetroleum's pattern.
var allCols = [
    "license_category", "license_type", "license_ai", "license_no", "lic_name", "lic_add1",
    "lic_add2", "lic_city", "lic_state", "lic_zip", "expire_date", "ssno",
    "recnum", "recnumb", "employed_by", "co_license_no", "date_first_issued", "fee",
    "invoice_no", "date_paid", "next_page", "warning_date_1", "reason_1", "warning_date_2",
    "reason_2", "warning_date_3", "reason_3", "suspend_date", "reason_suspend", "status",
    "date_entered", "comment", "batchid"
]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
