%dw 2.0
output application/java

var add1 = vars.row.add1 default ""
var add2 = vars.row.add2 default ""
var hasPOBox1 = (lower(add1) replace "." with "") contains "po box"
var hasPOBox2 = (lower(add2) replace "." with "") contains "po box"
var bothPopulated = (add1 != "") and (add2 != "")
var isMailing = vars.addressType == "Mailing"

// zip is an Access-exported numeric column, same leading-zero-loss/trailing-".0" risk as
// jobno/ReferenceNumber elsewhere — strip any decimal artifact, then zero-pad back to 5 digits
// (e.g. "2907" -> "02907"), 2026-07-28
fun padZip(z) = do {
    var stripped = (z default "" splitBy ".")[0]
    var len = sizeOf(stripped)
    ---
    if (stripped == "") ""
    else if (len < 5) ("00000"[0 to (4 - len)] ++ stripped)
    else stripped
}

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
    PostalCode: padZip(vars.row.zip),
    Country: "United States"
}
