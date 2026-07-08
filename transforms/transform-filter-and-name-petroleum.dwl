%dw 2.0
output application/java
---
(payload filter (row) -> ((row.licenseno default "") splitBy "." )[0] matches /^[1-9]\d*$/)
  map (row) -> row ++ {
      licenseno: (row.licenseno default "" splitBy ".")[0]
  }
