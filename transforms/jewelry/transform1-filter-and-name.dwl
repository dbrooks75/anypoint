%dw 2.0
output application/java
---
(payload filter (row) -> (row.jobno default "") matches /^CS-.+/)
  map (row) -> (row - "ID") ++ { id: row.ID }
