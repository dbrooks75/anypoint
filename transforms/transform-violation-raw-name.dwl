%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Reused for both of Elevators' violation source files: violation.unl (Current),
// hist_viol.unl (Historical). vars.sourceFileType must be set to "Current"/"Historical"
// before each call, same pattern as transform-laborstd-raw-name.dwl.
var allCols = [
    "recnumb", "unit_no", "batchid", "owc_ltr1_date", "owc_ltr2_date", "owc_ltr3_date",
    "shutdown_ltr_date", "first_ltr_date", "reas_time_no", "first_15day_flg", "viol_abtmnt_date", "full_compl_date",
    "comments", "data_entry_date", "updated_last", "first_hear_status", "first_hear_date", "sec_ltr_date",
    "penalty_date", "sec_15day_flg", "sec_hear_status", "sec_hear_date", "third_ltr_date", "cert_revo_date",
    "third_15day_flg", "third_hear_status", "third_hear_date", "fine_amt_pd", "date_fine_pd", "viol_status",
    "owc_ltr_printed", "day_31_viol", "day_46_viol", "day_91_viol", "viol_shutdown", "day_31_owc",
    "day_46_owc", "day_91_owc", "owc_shutdown", "hearing_date", "shutdown_date", "abate_date"
]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
