%dw 2.0
output application/java

fun fixFein(fein: String) = do {
    var stripped = fein replace /-/ with ""
    ---
    if (stripped == "") ""
    else if (sizeOf(stripped) == 9) stripped[0 to 1] ++ "-" ++ stripped[2 to 8]
    else stripped
}

var businessEntityTypes = {
    "I": "Sole Proprietorship",
    "S": "Sole Proprietorship",
    "P": "General Partnership",
    "C": "Corporation for Profit",
    "1": "Corporation for Profit"
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
    Federal_Tax_ID__c: fixFein(vars.row.fein default ""),
    Name: vars.row.name,
    DBA_Name__c: vars.row.company,
    Business_Entity_Type__c: businessEntityTypes[vars.row.bustype default ""] default "",
    SicDesc: vars.row.sic,
    BillingStreet: (vars.row.add1 default "") ++
                   (if ((vars.row.add2 default "") != "") " " ++ (vars.row.add2 default "") else ""),
    BillingCity: vars.row.city,
    BillingState: stateNames[vars.row.state default ""] default (vars.row.state default ""),
    BillingPostalCode: vars.row.zip
}
