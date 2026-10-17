%dw 2.0
import recnumbKey from usermodules::Utils
output application/java

// Groups company.csv rows by recnumb + SourceFileType, built once before the For Each so each
// row's match is a key lookup instead of a scan. Rows with a blank recnumb are left out.
// A key holding more than one row = ambiguous match, skipped and logged by the caller.
---
(payload filter (c) -> recnumbKey(c.recnumb, c.SourceFileType) != "")
    groupBy (c) -> recnumbKey(c.recnumb, c.SourceFileType)
