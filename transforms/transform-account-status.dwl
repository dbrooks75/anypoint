%dw 2.0
output application/java

var matchingRows = vars.arRows filter (row) -> row.jobno == vars.row.jobno

var oldestDepositDate = if (sizeOf(matchingRows) > 0)
    (matchingRows orderBy (row) -> row.deposit_date as Date {format: "M/d/yyyy"})[0].deposit_date
  else null
---
{
    Account__c: vars.accountId,
    Effective_Date__c: if ((oldestDepositDate default "") != "") oldestDepositDate as Date {format: "M/d/yyyy"} else null,
    Status__c: "Active"
}
