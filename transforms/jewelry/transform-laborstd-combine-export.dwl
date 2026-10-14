%dw 2.0
output application/csv
---
vars.currentRows ++ vars.historicalRows
