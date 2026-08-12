%dw 2.0
output application/java

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
    RecordTypeId: vars.accountRecordTypeId,
    Name: vars.row.compname,
    DBA_Name__c: vars.row.respparty,
    BillingStreet: (vars.row.add1 default "") ++
                   (if ((vars.row.add2 default "") != "") " " ++ (vars.row.add2 default "") else ""),
    BillingCity: vars.row.city,
    BillingStateCode: upper(vars.row.state default ""),
    BillingPostalCode: padZip(vars.row.zip),
    Preferred_Method_of_Comm__c: "Mail",
    Conversion_Identifier__c: "R1-Conversion",
    OwnerId: vars.ownerId
}
