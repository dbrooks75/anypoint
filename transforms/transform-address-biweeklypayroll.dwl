%dw 2.0
output application/java

var isCompany = vars.locationName == "Company"

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
---
{
    LocationType: "Business Site",
    AddressType: vars.addressType,
    ParentId: vars.locationId,
    Street: if (isCompany) (vars.row.CompanyAddr default "") else (vars.row.CorpOfficeAddr default ""),
    City: if (isCompany) (vars.row.CompanyCity default "") else (vars.row.CorpOfficeCity default ""),
    StateCode: if (isCompany) (vars.row.CompanyState default "") else (vars.row.CorpOfficeState default ""),
    PostalCode: if (isCompany) padZip(vars.row.CompanyZip) else padZip(vars.row.CorpOfficeZip),
    Country: "United States"
}
