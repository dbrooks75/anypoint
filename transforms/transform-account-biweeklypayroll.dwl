%dw 2.0
output application/java

fun fixFein(fein: String) = do {
    var stripped = fein replace /-/ with ""
    ---
    if (stripped == "") ""
    else if (sizeOf(stripped) == 9) stripped[0 to 1] ++ "-" ++ stripped[2 to 8]
    else stripped
}

var stateNames = {
    "AL": "Alabama",      "AK": "Alaska",         "AZ": "Arizona",       "AR": "Arkansas",
    "CA": "California",   "CO": "Colorado",        "CT": "Connecticut",   "DE": "Delaware",
    "FL": "Florida",      "GA": "Georgia",          "HI": "Hawaii",        "ID": "Idaho",
    "IL": "Illinois",     "IN": "Indiana",          "IA": "Iowa",          "KS": "Kansas",
    "KY": "Kentucky",     "LA": "Louisiana",        "ME": "Maine",         "MD": "Maryland",
    "MA": "Massachusetts","MI": "Michigan",          "MN": "Minnesota",     "MS": "Mississippi",
    "MO": "Missouri",     "MT": "Montana",           "NE": "Nebraska",      "NV": "Nevada",
    "NH": "New Hampshire","NJ": "New Jersey",        "NM": "New Mexico",    "NY": "New York",
    "NC": "North Carolina","ND": "North Dakota",     "OH": "Ohio",          "OK": "Oklahoma",
    "OR": "Oregon",       "PA": "Pennsylvania",     "RI": "Rhode Island",  "SC": "South Carolina",
    "SD": "South Dakota", "TN": "Tennessee",        "TX": "Texas",         "UT": "Utah",
    "VT": "Vermont",      "VA": "Virginia",         "WA": "Washington",    "WV": "West Virginia",
    "WI": "Wisconsin",    "WY": "Wyoming",          "DC": "District of Columbia"
}
---
{
    RecordTypeId: vars.accountRecordTypeId,
    Name: vars.row.CompanyName,
    Federal_Tax_ID__c: fixFein(vars.row.CompanyFEIN default ""),
    DBA_Name__c: "",
    Business_Entity_Type__c: "Customer",
    BillingStreet: vars.row.CompanyAddr,
    BillingCity: vars.row.CompanyCity,
    BillingState: stateNames[vars.row.CompanyState default ""] default (vars.row.CompanyState default ""),
    BillingPostalCode: vars.row.CompanyZip
}
