%dw 2.0
output application/java

// Generic column-count validator, reused before every entity's raw-name transform
// (parameterized via vars.expectedColCount, set before each call). Checks every row's raw
// pluck'd value count against the confirmed schema for that table — catches a row whose column
// count doesn't match before that silently corrupts downstream data: a row with fewer raw
// fields than expected leaves trailing renamed fields null; a row with more raw fields than
// expected silently drops the extras. Neither throws on its own, so this makes it loud instead.
var mismatches = payload map ((row, idx) -> {
    rowIndex: idx + 1,
    actualCount: sizeOf(row pluck $)
}) filter (r) -> r.actualCount != vars.expectedColCount
---
{
    totalRows: sizeOf(payload),
    expectedColCount: vars.expectedColCount,
    mismatchCount: sizeOf(mismatches),
    mismatches: mismatches
}
