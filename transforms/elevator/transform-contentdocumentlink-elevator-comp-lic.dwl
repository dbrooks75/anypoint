%dw 2.0
output application/java

// Links the ContentNote to the BLA, same as Petroleum/BiWeeklyPayroll
---
{
    ContentDocumentId: vars.contentNoteId,
    LinkedEntityId: vars.blaId,
    ShareType: "V",
    Visibility: "InternalUsers"
}
