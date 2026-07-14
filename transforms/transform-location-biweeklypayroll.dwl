%dw 2.0
output application/java

var rid = vars.row.RID default ""
---
[
    {
        LocationType: "Business Site",
        Name: "Company",
        Description: "Bi-Weekly address for RID " ++ rid
    },
    {
        LocationType: "Business Site",
        Name: "Corporate",
        Description: "Bi-Weekly corporate address for RID " ++ rid
    }
]
