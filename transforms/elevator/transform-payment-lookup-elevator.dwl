%dw 2.0
import recnumbKey from usermodules::Utils
output application/java

// Groups payment.csv rows (vars.paymentRows) by recnumb + SourceFileType, the same key as the company
// match, so each comp_lic row's payments are one key lookup (vars.paymentsByKey). Blank recnumbs are
// dropped so they never match.
---
(vars.paymentRows filter (p) -> recnumbKey(p.recnumb, p.SourceFileType) != "")
    groupBy (p) -> recnumbKey(p.recnumb, p.SourceFileType)
