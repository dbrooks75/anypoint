%dw 2.0
output application/java

// Used only for hi_license.unl (Historical) — confirmed 2026-08-26 this file has 32 columns,
// not license.unl's 33: missing "license_ai" (originally column 3). Same class of bug as
// hi_elevator_pr.unl / hi_comp_lic.unl. Builds the row field-by-field so license_ai sits as
// null at its ORIGINAL position (3), matching transform-elevator-license-raw-name.dwl's key
// order exactly, rather than appending it at the end where DataWeave's CSV writer would
// misalign it against license.unl's Current rows once combined in
// transform-elevator-license-combine-export.dwl.
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    {
        license_category: values[0],
        license_type: values[1],
        license_ai: null,
        license_no: values[2],
        lic_name: values[3],
        lic_add1: values[4],
        lic_add2: values[5],
        lic_city: values[6],
        lic_state: values[7],
        lic_zip: values[8],
        expire_date: values[9],
        ssno: values[10],
        recnum: values[11],
        recnumb: values[12],
        employed_by: values[13],
        co_license_no: values[14],
        date_first_issued: values[15],
        fee: values[16],
        invoice_no: values[17],
        date_paid: values[18],
        next_page: values[19],
        warning_date_1: values[20],
        reason_1: values[21],
        warning_date_2: values[22],
        reason_2: values[23],
        warning_date_3: values[24],
        reason_3: values[25],
        suspend_date: values[26],
        reason_suspend: values[27],
        status: values[28],
        date_entered: values[29],
        comment: values[30],
        batchid: values[31],
        SourceFileType: vars.sourceFileType
    }
}
