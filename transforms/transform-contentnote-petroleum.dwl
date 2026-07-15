%dw 2.0
output application/java

var certificate = vars.row.certificate default ""
var certifDmv = vars.row.certif_dmv default ""
var certifGu = vars.row.certif_gu default ""
var comments = vars.row.comments default ""

var html = "<p>Certificate: " ++ certificate ++ "</p>" ++
           "<p>Certificate (DMV): " ++ certifDmv ++ "</p>" ++
           "<p>Certificate GU: " ++ certifGu ++ "</p>" ++
           "<p>Comments: " ++ comments ++ "</p>"
---
{
    Title: "Petroleum Conversion",
    Content: html
}
