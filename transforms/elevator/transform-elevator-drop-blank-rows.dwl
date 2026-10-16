%dw 2.0
output application/java

// Generic blank-row filter, reused after every entity's raw-name transform regardless of column
// shape. A row counts as "blank" if every SOURCE field is an empty string after trim — excludes
// the SourceFileType key we append ourselves (transform-*-raw-name.dwl), since that's never
// blank and would otherwise prevent any row from ever counting as blank. classification's
// transform doesn't append SourceFileType at all, so removing a key that isn't present there is
// a harmless no-op. Confirmed 2026-08-24: blank rows get dropped, with the dropped count logged,
// not silently discarded.
// Uses filter/sizeOf instead of `every` (fixed 2026-08-25) -- `every` threw "unable to resolve
// reference of: 'every'" in Studio, same class of issue this project already hit with `some`
// needing an explicit dw::core::Arrays import (see transform-bla-petroleum.dwl's licenseno-
// padding note). filter/sizeOf needs no import and is used everywhere else in this project.
fun isBlank(row) = sizeOf((row - "SourceFileType") pluck $ filter ((v) -> (v default "") != "")) == 0

var kept = payload filter (row) -> not isBlank(row)
---
{
    keptRows: kept,
    sourceCount: sizeOf(payload),
    keptCount: sizeOf(kept),
    droppedCount: sizeOf(payload) - sizeOf(kept)
}
