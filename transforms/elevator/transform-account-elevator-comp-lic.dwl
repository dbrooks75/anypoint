%dw 2.0
output application/java

// zip is an Access-exported numeric column, same leading-zero-loss/trailing-".0" risk as
// elsewhere on this project — strip any decimal artifact, then zero-pad back to 5 digits
// (e.g. "2907" -> "02907")
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
    RecordTypeId: vars.accountRecordTypeId,
    Name: vars.row.name,
    BillingStreet: (vars.row.add1 default "") ++
                   (if ((vars.row.add2 default "") != "") " " ++ (vars.row.add2 default "") else ""),
    BillingCity: vars.row.city,
    BillingStateCode: upper(vars.row.state default ""),
    BillingPostalCode: padZip(vars.row.zip),
    Phone: vars.row.phone,
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1.1 - Conversion",
    OwnerId: vars.ownerId
}
