%dw 2.0
output application/java
---
payload.items map ((item, idx) -> {
    locationId: if (item.exception == null) item.payload.id else null,
    addressType: if (vars.locationList[idx].Name == "Mailing") "Mailing" else "Physical",
    success: item.exception == null,
    errorCode: if (item.exception != null) item.exception.statusCode else null,
    errorMessage: if (item.exception != null) item.exception.message else null
})
