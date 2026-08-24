%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/csv header=true, quoteValues=true

// Elevators' classification lookup table — elev_class (single-letter code) / elev_desc
// (description). Single source file, classification.unl, no Current/Historical/Private split
// and no SourceFileType needed (confirmed 2026-08-24) — unlike the other six entities, this
// transform goes straight from raw .unl to the final CSV in one step since there's nothing to
// combine. Confirmed values, 13 rows (not the originally estimated 10), for reference only —
// not hardcoded here, this transform just parses whatever's actually in the file: A=WIND
// TURBINE, D=DUMBWAITER, E=ESCALATOR, F=FREIGHT, H=PERSONAL HOIST, I=IPL, L=LULA, M=MATERIAL
// LIFT, P=PASSENGER, S=STAIRLIFT, T=PRIVATE ELEVETTE, V=VPL, W=MVWK.
var allCols = ["elev_class", "elev_desc"]
---
payload map (row) -> do {
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item)
}
