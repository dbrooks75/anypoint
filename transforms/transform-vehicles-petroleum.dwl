%dw 2.0
output application/json

// vars.truckRows: one row per licenseno, TrucksReg01/02 (or TrucksHis01/02) already joined —
// see flow-designs.md section 6 Vehicles note for the open question on how that join happens.
var licenseno = vars.row.licenseno default ""
var truckRow = (vars.truckRows filter (row) -> (row.licenseno default "") == licenseno)[0] default {}

// Slot columns have no leading zero (truck_make1 .. truck_make56), continuous across
// TrucksReg01/TrucksHis01 (1-39) and TrucksReg02/TrucksHis02 (40-56) — see flow-designs.md.
// equipment_no / tested_sealed (TrucksReg) / date_tested (TrucksHis) are not used in this JSON.
// TrucksHis names the plate column differently (reg_plate_numbN, not reg_truck_numbN like
// TrucksReg) — vars.truckRows mixes both sources, so fall back to the TrucksHis name.
var trucks = ((1 to 56) map (n) -> do {
    var suffix = n as String
    var rawMake = truckRow[("truck_make" ++ suffix)]
    var rawYear = truckRow[("year" ++ suffix)]
    var rawPlate = (truckRow[("reg_truck_numb" ++ suffix)]) default (truckRow[("reg_plate_numb" ++ suffix)])
    ---
    if ((rawMake default "") != "" or (rawYear default "") != "" or (rawPlate default "") != "")
        {
            inService: true,
            vin: "",
            // Placeholder — see dev-questions.md for what this should actually be
            registrationExpiry: "2026-04-09",
            state: "RI",
            plateNumber: rawPlate default "",
            model: "",
            year: rawYear default "",
            make: rawMake default ""
        }
    else null
}) filter (t) -> t != null

var columns = [
    { "type": "text", fieldName: "make", label: "Make" },
    { "type": "picklist", fieldName: "year", label: "Year" },
    { "type": "text", fieldName: "model", label: "Model" },
    { "type": "text", fieldName: "plateNumber", label: "Plate Number" },
    { "type": "picklist", fieldName: "state", label: "State" },
    { "type": "date", fieldName: "registrationExpiry", label: "Registration Exp. Date" },
    { "type": "text", fieldName: "vin", label: "Vehicle Number" },
    { "type": "boolean", fieldName: "inService", label: "Out of Service" }
]
---
{
    rows: trucks,
    columns: columns
}
