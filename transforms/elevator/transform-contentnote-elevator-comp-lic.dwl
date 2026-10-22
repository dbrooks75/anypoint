%dw 2.0
output application/java

// One ContentNote per BLA (mapping spec, BHJ 2026.10.15): each source field as "label: value", label = the
// comp_lic column name, value left blank when the source is blank. Plain HTML, one <p> per field — no Base64,
// the connector encodes rich-text Content itself (flow-designs.md section 6).
var fields = ["warning_date_1", "reason_1", "warning_date_2", "reason_2", "warning_date_3", "reason_3",
              "suspend_date", "reason_suspend", "comment"]

var html = (fields map (f) -> "<p>" ++ f ++ ": " ++ ((vars.row[f] default "") as String) ++ "</p>") joinBy ""
---
{
    // Mapping spec, BHJ 2026.07.07: "Set to Service Provider Conversion"
    Title: "Service Provider Conversion",
    Content: html,
    OwnerId: vars.ownerId
}
