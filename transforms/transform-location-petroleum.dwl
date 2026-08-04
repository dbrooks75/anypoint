%dw 2.0
output application/java

var licenseno = vars.row.licenseno default ""

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
    location("Physical Location")
]
