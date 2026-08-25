%dw 2.0
output application/java

// Elevators' own "payments" table (invoices + payments received against them) — reused for
// both source files: payments.unl (Current), hi_payments.unl (Historical). vars.sourceFileType
// must be set to "Current"/"Historical" before each call. Named
// transform-elevator-payments-raw-name.dwl (not transform-payments-raw-name.dwl) to avoid
// confusion with this project's existing singular transform-payment.dwl/-petroleum.dwl
// (Jewelry/Petroleum's Payment__c create transforms) — this is an unrelated Elevators-specific
// raw source table, plural naming intentional (matches the actual source table name).
// No input directive here (corrected 2026-08-25) -- the File Read component's own MIME
// Type tab (application/csv, quote=NUL, separator=|, header=false) parses the raw .unl
// before payload reaches this transform, matching ImportSourceDataPetroleum's pattern.
var allCols = [
    "recnumb", "predacc", "acc", "bill_or_pay", "hold_certif", "invoice_no",
    "invoice_date", "location", "insp_date", "amt_billed", "prev_billed", "not_billed",
    "no_charge", "other", "state_or_insur", "certif_begin", "certif_end", "miscellaneous",
    "s_ins_fee_pas_hyd", "s_ins_fee_frt_hyd", "s_insp_fee_escal", "s_ins_fee_mvgwalk", "s_insp_fee_dumb", "s_insp_fee_vwcl",
    "s_ins_fee_elevet", "recip_convey", "s_ins_fee_iwcl", "s_ins_fee_matllift", "reinsp_elev", "reinsp_other",
    "delq_pymt", "dup_certif", "insp_exam_renew", "comp_lic_renew", "mech_lic_renew", "appr_lic_renew",
    "new_install", "fines", "misc_bill_amt", "i_ins_fee_pas_hyd", "i_ins_fee_pas_cab", "i_ins_fee_frt_hyd",
    "i_ins_fee_frt_cab", "i_insp_fee_escal", "i_insp_fee_dumb", "i_insp_fee_vwcl", "i_ins_fee_elevet", "paidp",
    "payrecdate", "amtreceived", "receivedby", "credit_card", "check_no", "moneyord_no",
    "cashrecpt_no", "deposit_voucher", "deposit_date", "batchid", "overtime_hrs", "s_ins_fee_strlift",
    "delinquent", "ltr_printed_date"
]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
