%dw 2.0
output application/java

var jobno = vars.row.jobno default ""

fun location(name: String) =
    {
        LocationType: "Business Site",
        Name: name,
        Description: "Jewelry " ++ name ++ " Address for Job No " ++ jobno,
        OwnerId: vars.ownerId
    }
---
[
    location("Mailing"),
    location("Physical Location")
]
