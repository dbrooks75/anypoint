%dw 2.0
output application/java

var add1 = vars.row.add1 default ""
var add2 = vars.row.add2 default ""
var hasPOBox1 = lower(add1) contains "po box"
var hasPOBox2 = lower(add2) contains "po box"
var bothPopulated = (add1 != "") and (add2 != "")
var isMailing = vars.addressType == "Mailing"

var street =
    if (bothPopulated and (hasPOBox1 or hasPOBox2))
        if (isMailing)
            if (hasPOBox1) add1 else add2
        else
            if (hasPOBox1) add2 else add1
    else if (bothPopulated)
        add1 ++ " " ++ add2
    else
        if (add1 != "") add1 else add2
---
{
    LocationType: "Business Site",
    AddressType: vars.addressType,
    ParentId: vars.locationId,
    Street: street,
    City: vars.row.city default "",
    StateCode: vars.row.state default "",
    PostalCode: vars.row.zip default "",
    Country: "United States"
}
