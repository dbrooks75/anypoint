%dw 2.0
output application/java

var rid = vars.row.RID default ""
var corpOfficeAddr = vars.row.CorpOfficeAddr default ""
---
[
    {
        LocationType: "Business Site",
        Name: "Company",
        Description: "Bi-Weekly address for RID " ++ rid
    },
    if (corpOfficeAddr != "")
        {
            LocationType: "Business Site",
            Name: "Corporate",
            Description: "Bi-Weekly corporate address for RID " ++ rid
        }
    else null
] filter (l) -> l != null
