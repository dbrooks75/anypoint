%dw 2.0
import recnumbKey, parseDate from usermodules::Utils
output application/java

// This row's payment.csv rows (vars.paymentsByKey, matched on recnumb + SourceFileType), for the invoices.
// Rows where any column contains "permit" (any case) are dropped (user, 2026-10-21). Then sorted
// oldest first by payrecdate; a blank payrecdate defaults to 1/1/1900 (user, 2026-10-21), so it sorts first.
var payments = vars.paymentsByKey[recnumbKey(vars.row.recnumb, vars.row.SourceFileType)] default []

fun hasPermit(p) = sizeOf(valuesOf(p) filter (v) -> (lower((v default "") as String) contains "permit")) > 0
---
(payments filter (p) -> not hasPermit(p))
    orderBy (p) -> parseDate(p.payrecdate) default |1900-01-01|
