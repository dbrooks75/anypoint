%dw 2.0
output application/java

var add1 = vars.row.add1 default ""
var add2 = vars.row.add2 default ""
var hasPOBox1 = (lower(add1) replace "." with "") contains "po box"
var hasPOBox2 = (lower(add2) replace "." with "") contains "po box"
var bothPopulated = (add1 != "") and (add2 != "")

var licenseno = vars.row.licenseno default ""

fun location(name: String) =
    {
        LocationType: "Business Site",
        Name: name,
        Description: "Petroleum " ++ name ++ " Address for License No " ++ licenseno
    }
---
if (bothPopulated and (hasPOBox1 or hasPOBox2))
    [
        location("Mailing"),
        location("Physical Location")
    ]
else
    [ location("Mailing") ]
