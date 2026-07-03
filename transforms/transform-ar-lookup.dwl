%dw 2.0
output application/java
---
(vars.blaJobnoLog filter (r) -> r.jobno == vars.row.jobno)[0] default {}
