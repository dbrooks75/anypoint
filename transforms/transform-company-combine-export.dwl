%dw 2.0
output application/csv header=true, quoteValues=true
---
vars.currentCompanyRows ++ vars.historicalCompanyRows ++ vars.privateCompanyRows
