%dw 2.0
output application/java

var knownTitles = [
    "PRES", "PRES/TREAS", "PRES/SEC", "TREAS", "SEC", "VP",
    "PTNR", "PARTNER", "OWNER", "DIR", "MGR", "MG",
    "BRANCH MG", "BRANCH MGR"
]

fun stripTitle(name: String) = do {
    var cleaned = trim(name replace /,/ with "")
    var words = (cleaned splitBy " ") filter (w) -> w != ""
    var count = sizeOf(words)
    var lastWord = upper(words[-1] default "")
    var twoWordTitle = if (count >= 3) (upper(words[-2] default "") ++ " " ++ lastWord) else ""
    ---
    if (count >= 3 and (knownTitles contains twoWordTitle))
        { namePart: words[0 to -3] joinBy " ", title: twoWordTitle }
    else if (count >= 2 and (knownTitles contains lastWord))
        { namePart: words[0 to -2] joinBy " ", title: lastWord }
    else
        { namePart: cleaned, title: "" }
}

fun parseName(raw: String) = do {
    var result = stripTitle(raw)
    var words = (result.namePart splitBy " ") filter (w) -> w != ""
    var count = sizeOf(words)
    ---
    {
        firstName: words[0] default "",
        middleName: if (count >= 3) (words[1 to count - 2] joinBy " ") else null,
        lastName: if (count >= 2) words[-1] else null,
        extractedTitle: result.title
    }
}

fun makeContact(respparty, title) = do {
    var parsed = parseName(respparty default "")
    ---
    {
        FirstName: parsed.firstName,
        MiddleName: parsed.middleName,
        LastName: parsed.lastName,
        Title: if ((title default "") != "") title
               else if (parsed.extractedTitle != "") parsed.extractedTitle
               else null,
        AccountId: vars.accountId,
        Phone: null,
        TitleType: "Other"
    }
}
---
[
    if ((vars.row.respparty1 default "") != "") makeContact(vars.row.respparty1, vars.row.title1) else null,
    if ((vars.row.respparty2 default "") != "") makeContact(vars.row.respparty2, vars.row.title2) else null,
    if ((vars.row.respparty3 default "") != "") makeContact(vars.row.respparty3, vars.row.title3) else null,
    if ((vars.row.respparty4 default "") != "") makeContact(vars.row.respparty4, vars.row.title4) else null
] filter (c) -> c != null
