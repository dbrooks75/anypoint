%dw 2.0
output application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
---
vars.currentRows ++ vars.historicalRows
