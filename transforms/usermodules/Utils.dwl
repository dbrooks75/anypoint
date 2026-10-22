%dw 2.0

// Shared helper functions, imported by transforms instead of copying the helper into each one.
// In Studio this file lives at src/main/resources/usermodules/Utils.dwl; import it under a transform's
// %dw 2.0 line with:
//     import * from usermodules::Utils                  (everything)
//     import padZip, properCase from usermodules::Utils  (just what's needed)
// Uses core functions only (no extra imports) — same caution as elsewhere on this project about
// less-common stdlib functions not resolving in Studio (see the some/every issues).
// Started with Elevator (2026-10-16); Jewelry/Petroleum/BiWeeklyPayroll still carry their own copies.

// Strips an Access-exported decimal artifact: "12345.0" -> "12345".
fun stripDecimal(v) = (v default "" splitBy ".")[0]

// zip is an Access-exported numeric column, same leading-zero-loss/trailing-".0" risk as
// elsewhere on this project — strip any decimal artifact, then zero-pad back to 5 digits
// (e.g. "2907" -> "02907")
fun padZip(z) = do {
    var stripped = (z default "" splitBy ".")[0]
    var len = sizeOf(stripped)
    ---
    if (stripped == "") ""
    else if (len < 5) ("00000"[0 to (4 - len)] ++ stripped)
    else stripped
}

// Left-pads a value with zeros to the given width, after stripping any ".0" export artifact:
// zeroPad("27", 7) -> "0000027". Longer values are returned unchanged; blank/null -> "".
fun zeroPad(v, width) = do {
    var stripped = stripDecimal(v) default ""
    var len = sizeOf(stripped)
    ---
    if (stripped == "") ""
    else if (len < width) (((1 to (width - len)) map (i) -> "0") joinBy "") ++ stripped
    else stripped
}

// Parses an M/d/yyyy date string (the Access export's date format) to a Date; blank/null -> null
fun parseDate(s) = if ((s default "") != "") (s as String) as Date {format: "M/d/yyyy"} else null

// Date -> DateTime at noon UTC, for Salesforce DateTime fields. Noon (not midnight) so the date shows
// as the same calendar day in every US timezone (flow-designs.md, "RESOLVED 2026-07-27"). null -> null
fun noonUtc(d) = if (d == null) null
    else ((d as String {format: "yyyy-MM-dd"}) ++ "T12:00:00Z") as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}

// ---- Contacts ---------------------------------------------------------------------------------

// Splits a "FIRST [MIDDLE...] LAST" name: first word -> firstName, last word -> lastName, any words
// between -> middleName. A single word goes to lastName (Contact.LastName is required in
// Salesforce, FirstName isn't). Blank/null -> all null.
fun parseName(raw) = do {
    var words = ((raw default "") splitBy " ") filter (w) -> w != ""
    var count = sizeOf(words)
    ---
    {
        firstName: if (count >= 2) words[0] else null,
        middleName: if (count >= 3) (words[1 to count - 2] joinBy " ") else null,
        lastName: if (count >= 1) words[-1] else null
    }
}

// Returns the email if it looks like one (something@something.something), otherwise null
fun cleanEmail(email) = do {
    var e = trim(email default "")
    ---
    if (e matches /^[^\s@]+@[^\s@]+\.[^\s@]+$/) e else null
}

// ---- Elevator ---------------------------------------------------------------------------------

// Key for matching a row to company.csv: recnumb (decimal-stripped) + SourceFileType, the same
// pair the Access export joins on. "" when recnumb is blank, so blank recnumbs never match.
fun recnumbKey(recnumb, sourceFileType) = do {
    var r = stripDecimal(recnumb) default ""
    ---
    if (r == "") "" else r ++ "|" ++ (sourceFileType default "")
}

// ---- Mailing / Physical address rules (flow-designs.md section 2, "Mailing / Physical Location Rule") ----
// Same rules the retired work units duplicated across their Location and Address transforms.

// True if the line is a PO Box; periods stripped first so "P.O. Box" matches too
fun isPOBox(line) = (lower(line default "") replace "." with "") contains "po box"

// True when the only address line on file is a PO Box (one line populated, the other blank) —
// no real street address, so no Physical Location gets created
fun poBoxOnly(add1, add2) = do {
    var a1 = add1 default ""
    var a2 = add2 default ""
    ---
    ((a1 != "") != (a2 != "")) and (isPOBox(a1) or isPOBox(a2))
}

// Street for an Address__c of the given type ("Mailing" or "Physical"):
//   both lines populated, one a PO Box -> PO Box line for Mailing, the other line for Physical
//   both lines populated, no PO Box    -> both lines joined with a space
//   one line populated                 -> that line
fun streetFor(add1, add2, addressType) = do {
    var a1 = add1 default ""
    var a2 = add2 default ""
    var bothPopulated = (a1 != "") and (a2 != "")
    ---
    if (bothPopulated and (isPOBox(a1) or isPOBox(a2)))
        if (addressType == "Mailing")
            (if (isPOBox(a1)) a1 else a2)
        else
            (if (isPOBox(a1)) a2 else a1)
    else if (bothPopulated) a1 ++ " " ++ a2
    else if (a1 != "") a1
    else a2
}

// ---- properCase -------------------------------------------------------------------------------
// Converts upper-case source text to proper case, word by word (words split on single spaces, so
// spacing is preserved as-is):
//     "ACME ELEVATOR CO., INC."   -> "Acme Elevator Co., Inc."
//     "123 N MAIN ST APT 4B"      -> "123 N Main St Apt 4B"
//     "O'BRIEN-MCDONALD"          -> "O'Brien-McDonald"
//     "BANK OF AMERICA"           -> "Bank of America"
//     "P.O. BOX 12"               -> "P.O. Box 12"
// Can't tell an acronym from a word ("ABC ELEVATOR" -> "Abc Elevator") — add known acronyms to
// properCaseUpper. Null -> null.

// Words always kept upper case (compared with punctuation removed, so "LLC." and "(USA)" match)
var properCaseUpper = ["LLC", "LLP", "PC", "PA", "USA", "US", "PO", "NE", "NW", "SE", "SW",
                       "II", "III", "IV", "DBA", "RI"]

// Words lower-cased when not the first word
var properCaseLower = ["of", "and", "the", "at", "for", "in", "on", "by"]

// Upper-cases the first letter, lower-cases the rest; leading punctuation is skipped ("(acme)" -> "(Acme)")
fun capFirstLetter(w: String): String = do {
    var m = lower(w) scan /^([^a-z]*)([a-z])(.*)$/
    ---
    if (isEmpty(m)) lower(w) else m[0][1] ++ upper(m[0][2]) ++ m[0][3]
}

// O'Brien / D'Angelo: one letter, apostrophe, then capitalize the next letter ("John's" untouched)
fun fixApostrophe(w: String): String = do {
    var m = w scan /^([^A-Za-z]*[A-Za-z]')([a-z])(.*)$/
    ---
    if (isEmpty(m)) w else m[0][1] ++ upper(m[0][2]) ++ m[0][3]
}

// McDonald: capitalize the letter after a leading "Mc" (not "Mac" — would break "Machine")
fun fixMc(w: String): String = do {
    var m = w scan /^([^A-Za-z]*Mc)([a-z])(.*)$/
    ---
    if (isEmpty(m)) w else m[0][1] ++ upper(m[0][2]) ++ m[0][3]
}

fun properCaseWord(w: String, isFirst: Boolean): String = do {
    var letters = upper(w replace /[^A-Za-z]/ with "")
    ---
    if (w == "") w
    else if (properCaseUpper contains letters) upper(w)
    else if (w matches /^([A-Za-z]\.)+$/) upper(w)                  // initials: P.O., U.S.A.
    else if (w matches /^\d+(st|nd|rd|th|ST|ND|RD|TH)$/) lower(w)   // ordinals: 2ND -> 2nd
    else if (w matches /.*\d.*/) upper(w)                            // other numbers/units: 123, 4B, #12A
    else if ((not isFirst) and (properCaseLower contains lower(w))) lower(w)
    else ((w splitBy "-") map (part) -> fixMc(fixApostrophe(capFirstLetter(part)))) joinBy "-"
}

fun properCase(s) =
    if (s == null) null
    else ((s splitBy " ") map (w, i) -> properCaseWord(w, i == 0)) joinBy " "
