%dw 2.0
output application/java
---
(payload filter (row) -> ((row.jobno default "") splitBy "." )[0] matches /^[1-9]\d*$/)
  map (row) -> row ++ {
      jobno: (row.jobno default "" splitBy ".")[0],
      licenseno: (row.licenseno default "" splitBy ".")[0]
  }
