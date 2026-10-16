%dw 2.0
output application/csv header=true, quoteValues=true
---
vars.currentElevatorRows ++ vars.historicalElevatorRows ++ vars.privateElevatorRows
