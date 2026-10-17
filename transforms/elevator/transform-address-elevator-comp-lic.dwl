%dw 2.0
import padZip, streetFor from usermodules::Utils
output application/java

// Address comes from the matched company row (vars.company), not comp_lic
---
{
    LocationType: "Business Site",
    AddressType: vars.addressType,
    ParentId: vars.locationId,
    Street: streetFor(vars.company.add1, vars.company.add2, vars.addressType),
    City: vars.company.city default "",
    StateCode: upper(vars.company.state default ""),
    PostalCode: padZip(vars.company.zip),
    Country: "United States"
}
