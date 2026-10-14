%dw 2.0
output application/java
---
{
    ContentDocumentId: vars.contentNoteId,
    LinkedEntityId: vars.blaId,
    ShareType: "V",
    Visibility: "InternalUsers"
}
