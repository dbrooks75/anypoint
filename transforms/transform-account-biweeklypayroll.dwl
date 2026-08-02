%dw 2.0
output application/java

fun fixFein(fein: String) = do {
    var stripped = fein replace /-/ with ""
    ---
    if (stripped == "") ""
    else if (sizeOf(stripped) == 9) stripped[0 to 1] ++ "-" ++ stripped[2 to 8]
    else stripped
}

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
    BillingPostalCode: padZip(vars.row.CompanyZip),
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1-Conversion",
    OwnerId: vars.ownerId
}
