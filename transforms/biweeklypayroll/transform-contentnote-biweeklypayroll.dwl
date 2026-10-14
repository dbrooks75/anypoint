%dw 2.0
output application/java

var classificationInvolved = vars.row.ClassificationInvolved default ""

var html = "<p>Classification Involved: " ++ classificationInvolved ++ "</p>"
---
{
    Title: "Bi-Weekly Conversion",
    Content: html,
    OwnerId: vars.ownerId
}
