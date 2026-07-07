%dw 2.0
output application/java

var cols = ["fein", "recnumb", "appnumb", "name", "legalcode", "bustype", "zip", "sic",
            "predacc", "acc", "add1", "add2", "city", "state", "change_of_addr", "date_changed",
            "out_of_business", "company", "respparty1", "title1", "respparty2", "title2",
            "respparty3", "title3", "respparty4", "title4", "jobno", "issue_date", "tot_pymt", "batchid"]
---
payload map (row) -> do {
    var values = row pluck $
    ---
    (cols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        ++ { SourceFileType: vars.sourceFileType }
}
