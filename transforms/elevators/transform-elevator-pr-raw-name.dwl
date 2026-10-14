%dw 2.0
output application/java

// Used only for hi_elevator_pr.unl (Private) — confirmed 2026-08-25 this file has a DIFFERENT
// 70-column layout than elevator.unl/his_elev.unl's 72 columns (transform-elevator-raw-name.dwl):
// missing "device_active" (originally column 4) and "insp_date_due" (originally column 11).
// Corrected 2026-08-26: an earlier version of this file appended device_active/insp_date_due as
// extra keys at the END of the object (mirroring how SourceFileType is appended). That was wrong
// -- DataWeave's CSV writer does NOT reliably align columns by key name across rows with
// different key orders, so Private rows came out shifted once combined with Current/Historical
// rows in transform-elevator-combine-export.dwl. Fixed by building the object field-by-field so
// device_active/insp_date_due sit at their ORIGINAL positions (4 and 11), as null, matching
// transform-elevator-raw-name.dwl's key order exactly, not just its key set.
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    {
        serial_no: values[0],
        recnumb: values[1],
        co_license_no: values[2],
        device_active: null,
        building: values[3],
        name: values[4],
        add1: values[5],
        add2: values[6],
        city: values[7],
        last_insp_date: values[8],
        insp_date_due: null,
        next_insp_date: values[9],
        insp_by: values[10],
        certif_date: values[11],
        certif_num: values[12],
        safetest_date: values[13],
        classification: values[14],
        unit_no: values[15],
        location: values[16],
        bill_and_issue: values[17],
        bill_and_hold: values[18],
        no_chg_and_issue: values[19],
        no_chg_and_hold: values[20],
        manuf_by: values[21],
        carry_capacity: values[22],
        year_made: values[23],
        mach_type: values[24],
        control_type: values[25],
        car_safety_dev: values[26],
        loc_safety_dev: values[27],
        typ_safety_dev: values[28],
        overspeed_gov: values[29],
        trip_at: values[30],
        car_speed: values[31],
        current_acdc: values[32],
        no_cables: values[33],
        hoist_size: values[34],
        cwt_size: values[35],
        gov_size: values[36],
        form_of_drive: values[37],
        height: values[38],
        pit_depth: values[39],
        no_entrances: values[40],
        landing_gate: values[41],
        guid_rail_matl: values[42],
        interlocks: values[43],
        fire_rated: values[44],
        accessibility: values[45],
        out_of_service: values[46],
        oos_date: values[47],
        viol_letter: values[48],
        letter_date: values[49],
        rule_numbers: values[50],
        safety_test: values[51],
        under_repair: values[52],
        non_use: values[53],
        modernize: values[54],
        certif_held: values[55],
        broken_rope: values[56],
        dormant: values[57],
        batchid: values[58],
        three_year: values[59],
        five_year: values[60],
        safedate: values[61],
        permit_type: values[62],
        reinsp_date: values[63],
        reinsp_by: values[64],
        date_15days: values[65],
        final_date: values[66],
        install_code: values[67],
        alteration_date: values[68],
        permit_date: values[69],
        SourceFileType: vars.sourceFileType
    }
}
