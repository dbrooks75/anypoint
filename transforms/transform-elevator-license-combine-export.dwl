%dw 2.0
output application/csv header=true, quoteValues=true
---
vars.currentLicenseRows ++ vars.historicalLicenseRows
