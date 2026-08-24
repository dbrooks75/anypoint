%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Generic column-count validator, called directly on the raw File Read output — before the
// entity's raw-name transform runs, on purpose, so a short/long row is caught before renaming
// silently corrupts it (a short row leaves trailing renamed fields null; a long row silently
// drops the extras — neither throws on its own). Needs its own input directive (matching every
// raw-name transform's separator/quoteChar) since it has to parse the same raw .unl
// independently — a .unl extension doesn't auto-detect as CSV, and this step runs before
// anything else has parsed the payload. Parameterized via vars.expectedColCount, set before
// each call.
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
