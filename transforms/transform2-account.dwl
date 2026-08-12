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

var businessEntityTypes = {
    "I": "Sole Proprietorship",
    "S": "Sole Proprietorship",
    "P": "General Partnership",
    "C": "Corporation for Profit",
    "1": "Corporation for Profit"
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
    BillingStateCode: upper(vars.row.state default ""),
    BillingPostalCode: padZip(vars.row.zip),
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1-Conversion",
    OwnerId: vars.ownerId
}
