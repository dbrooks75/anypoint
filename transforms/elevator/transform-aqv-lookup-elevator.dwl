%dw 2.0
output application/java

// Active ESC AssessmentQuestionVersions (InitAssessmentQuestionVersionElevator) -> map keyed
// by BOTH Name and AssessmentQuestion.DeveloperName. Two different questions share the Name
// "ESC Date App Received" (DeveloperNames ESC_Date_App_Received and ESC_Date_Renewal_App_Received),
// so those two are looked up by DeveloperName; the rest by Name. Rows come back ordered by
// VersionNumber, and an existing key is replaced, so the latest version wins.
fun put(acc, key, item) = if (key == null) acc else (acc - key) ++ {(key): item}
---
payload reduce (item, acc = {}) ->
    put(put(acc, item.Name as String, item), item.AssessmentQuestion.DeveloperName, item)
