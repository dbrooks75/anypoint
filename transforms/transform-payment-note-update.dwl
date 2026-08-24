%dw 2.0
output application/java

var row = vars.matchedArRow
---
{
    Id: vars.payment.Id,
    Notes__c: "Deposit Voucher: " ++ (row.deposit_voucher default "") ++
              "; Deposit Date: " ++ (row.deposit_date default "") ++
              "; Budget Acc 1: " ++ (row.budget_acc1 default "") ++
              "; Budget Acc 2: " ++ (row.budget_acc2 default "") ++
              "; Remarks: " ++ (row.remarks default "")
}
