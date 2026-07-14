%dw 2.0
output application/java

var isCompany = vars.locationName == "Company"
---
{
    LocationType: "Business Site",
    AddressType: vars.addressType,
    ParentId: vars.locationId,
    Street: if (isCompany) (vars.row.CompanyAddr default "") else (vars.row.CorpOfficeAddr default ""),
    City: if (isCompany) (vars.row.CompanyCity default "") else (vars.row.CorpOfficeCity default ""),
    StateCode: if (isCompany) (vars.row.CompanyState default "") else (vars.row.CorpOfficeState default ""),
    PostalCode: if (isCompany) (vars.row.CompanyZip default "") else (vars.row.CorpOfficeZip default ""),
    Country: "United States"
}
