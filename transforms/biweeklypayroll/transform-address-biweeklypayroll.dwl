%dw 2.0
output application/java

// "Company" and "Physical Location" (2026-08-04, new) both read from Company* columns; only
// "Corporate" reads from CorpOffice* — inverted from the old isCompany check since two of the
// three Location names now share the same source columns
var isCorporate = vars.locationName == "Corporate"

// AddressType determined here from vars.locationName (2026-08-04) rather than reading an
// externally-set vars.addressType — "Corporate" is a valid picklist value on this org, so all
// three Location names map to a distinct AddressType, no collapsing "Physical Location"/"Corporate"
// into one value
var addressType =
    if (vars.locationName == "Company") "Mailing"
    else if (isCorporate) "Corporate"
    else "Physical"

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
    AddressType: addressType,
    ParentId: vars.locationId,
    Street: if (isCorporate) (vars.row.CorpOfficeAddr default "") else (vars.row.CompanyAddr default ""),
    City: if (isCorporate) (vars.row.CorpOfficeCity default "") else (vars.row.CompanyCity default ""),
    StateCode: if (isCorporate) (vars.row.CorpOfficeState default "") else (vars.row.CompanyState default ""),
    PostalCode: if (isCorporate) padZip(vars.row.CorpOfficeZip) else padZip(vars.row.CompanyZip),
    Country: "United States"
}
