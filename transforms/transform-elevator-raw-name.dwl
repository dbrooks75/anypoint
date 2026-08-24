%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Reused for all three of Elevators' elevator source files: elevator.unl (Current),
// his_elev.unl (Historical), hi_elevator_pr.unl (Private) — confirmed 2026-08-24 all three
// share this same 72-column layout. vars.sourceFileType must be set to "Current"/"Historical"/
// "Private" before each call, same pattern as transform-laborstd-raw-name.dwl.
// Column 50 ("oos_date") — confirmed 2026-08-24 this is a single column despite its raw source
// label reading like two words ("oos_date date"); persisted here under the simplified name.
var allCols = [
    "serial_no", "recnumb", "co_license_no", "device_active", "building", "name",
    "add1", "add2", "city", "last_insp_date", "insp_date_due", "next_insp_date",
    "insp_by", "certif_date", "certif_num", "safetest_date", "classification", "unit_no",
    "location", "bill_and_issue", "bill_and_hold", "no_chg_and_issue", "no_chg_and_hold", "manuf_by",
    "carry_capacity", "year_made", "mach_type", "control_type", "car_safety_dev", "loc_safety_dev",
    "typ_safety_dev", "overspeed_gov", "trip_at", "car_speed", "current_acdc", "no_cables",
    "hoist_size", "cwt_size", "gov_size", "form_of_drive", "height", "pit_depth",
    "no_entrances", "landing_gate", "guid_rail_matl", "interlocks", "fire_rated", "accessibility",
    "out_of_service", "oos_date", "viol_letter", "letter_date", "rule_numbers", "safety_test",
    "under_repair", "non_use", "modernize", "certif_held", "broken_rope", "dormant",
    "batchid", "three_year", "five_year", "safedate", "permit_type", "reinsp_date",
    "reinsp_by", "date_15days", "final_date", "install_code", "alteration_date", "permit_date"
]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
