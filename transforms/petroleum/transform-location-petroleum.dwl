%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""

// Skip Physical Location if the only address on file is a PO Box (one field populated, the
// other blank, and the populated one is a PO Box) — there's no real street address to create
// a Physical Location from in that case, added 2026-08-07
var add1 = vars.row.add1 default ""
var add2 = vars.row.add2 default ""
var hasPOBox1 = (lower(add1) replace "." with "") contains "po box"
var hasPOBox2 = (lower(add2) replace "." with "") contains "po box"
var onlyOnePopulated = (add1 != "") != (add2 != "")
var skipPhysical = onlyOnePopulated and (hasPOBox1 or hasPOBox2)

fun location(name: String) =
    {
        LocationType: "Business Site",
        Name: name,
        Description: "Petroleum " ++ name ++ " Address for License No " ++ licenseno,
        OwnerId: vars.ownerId
    }
---
[
    location("Mailing"),
    if (not skipPhysical) location("Physical Location") else null
] filter (l) -> l != null
