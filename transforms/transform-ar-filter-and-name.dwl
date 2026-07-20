%dw 2.0
output application/java
---
(payload filter (row) -> (row.jobno default "") matches /^CS-.+/)
  orderBy (row) -> if ((row.deposit_date default "") != "") row.deposit_date as Date {format: "M/d/yyyy"} else |0001-01-01|
