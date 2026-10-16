%dw 2.0
output application/java

// Used only for hi_comp_lic.unl (Historical) — confirmed 2026-08-26 this file has 29 columns,
// not comp_lic.unl's 30: missing "license_ai" (originally column 3). Same class of bug as
// hi_elevator_pr.unl (Private) — see transform-elevator-pr-raw-name.dwl. Builds the row
// field-by-field so license_ai sits as null at its ORIGINAL position (3), matching
// transform-comp-lic-raw-name.dwl's key order exactly, rather than appending it at the end
// where DataWeave's CSV writer would misalign it against comp_lic.unl's Current rows once
// combined in transform-comp-lic-combine-export.dwl.
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    {
        license_category: values[0],
        license_type: values[1],
        license_ai: null,
        co_license_no: values[2],
        expire_date: values[3],
        recnumb: values[4],
        name: values[5],
        add1: values[6],
        add2: values[7],
        city: values[8],
        state: values[9],
        zip: values[10],
        date_first_issued: values[11],
        fee: values[12],
        invoice_no: values[13],
        date_paid: values[14],
        next_page: values[15],
        warning_date_1: values[16],
        reason_1: values[17],
        warning_date_2: values[18],
        reason_2: values[19],
        warning_date_3: values[20],
        reason_3: values[21],
        suspend_date: values[22],
        reason_suspend: values[23],
        phone: values[24],
        status: values[25],
        date_entered: values[26],
        comment: values[27],
        batchid: values[28],
        SourceFileType: vars.sourceFileType
    }
}
