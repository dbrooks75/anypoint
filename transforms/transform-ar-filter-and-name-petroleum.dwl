%dw 2.0
output application/java
---
((payload filter (row) -> ((row.licenseno default "") splitBy "." )[0] matches /^[1-9]\d*$/)
  map (row) -> row ++ {
      licenseno: (row.licenseno default "" splitBy ".")[0]
  })
  orderBy (row) -> if ((row.deposit_date default "") != "") row.deposit_date as Date {format: "M/d/yyyy"} else |0001-01-01|
