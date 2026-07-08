%dw 2.0
output application/java

// Reused for both Current (TruckReg01/02) and Historical (TruckHis01/02) pairs —
// same "one transform, two Set Variable calls" reuse pattern as transform-laborstd-raw-name.dwl.
var part1 = vars.truckPart1Rows default []
var part2 = vars.truckPart2Rows default []

var part2ByLicense = part2 reduce (row, acc = {}) -> acc ++ {(row.licenseno as String): row}
---
// part1 (01, slots 1-39) carries licenseno/inspect_comp_code/inspect_comp; part2 (02, slots 40-56)
// adds tot_reg_trucks/batch_id — ++ merges the two into one row per licenseno, part2's fields winning
// on any key overlap (there shouldn't be any besides licenseno, which is identical either way)
part1 map (row) -> row ++ (part2ByLicense[(row.licenseno as String)] default {})
