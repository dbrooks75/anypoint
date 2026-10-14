%dw 2.0
output application/java

// Generic column-count validator, called directly on the File Read output — before the
// entity's raw-name transform runs, on purpose, so a short/long row is caught before renaming
// silently corrupts it (a short row leaves trailing renamed fields null; a long row silently
// drops the extras — neither throws on its own). No input directive needed here (corrected
// 2026-08-25) — the File Read component's own MIME Type tab (application/csv, quote=NUL,
// separator=|, header=false) already parses the raw .unl into an array before payload reaches
// this transform, matching ImportSourceDataPetroleum's pattern. Parameterized via
// vars.expectedColCount, set before each call.
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
