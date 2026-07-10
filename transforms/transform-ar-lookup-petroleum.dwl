%dw 2.0
output application/java
---
(vars.blaLicenseLog filter (r) -> r.licenseno == vars.row.licenseno)[0] default {}
