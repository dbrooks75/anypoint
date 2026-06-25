# Flow Designs

## 1. Delete Flow — Remove Records by Company Name

Reads a CSV of company names and deletes all related Salesforce records in the correct order (children before parents).

### Trigger File
`C:\data\AccountDeletes.csv` — one column: `CompanyName`

### Flow Structure
```
On New or Updated File (C:\data\, AccountDeletes.csv)
  → Transform Message (parse CSV to Java list)
  → For Each (loop over company names)
      → Salesforce Query: SELECT Id FROM Account WHERE Name = ':companyName'
      → Set Variable (accountId = payload[0].Id)
      → Salesforce Query: SELECT Id FROM Invoice__c WHERE Account__c = ':accountId'
      → For Each (loop over invoices)
          → Set Variable (invoiceId)
          → Salesforce Query: SELECT Id FROM Payment__c WHERE Invoice__c = ':invoiceId'
          → Salesforce Delete (Payment__c)
          → Salesforce Query: SELECT Id FROM InvoiceLine__c WHERE Invoice__c = ':invoiceId'
          → Salesforce Delete (InvoiceLine__c)
          → Salesforce Delete (Invoice__c)
  → Logger
```

### Delete Order (Important — children must be deleted before parents)
1. Payment__c (child of Invoice__c via Payment__c.Invoice__c)
2. InvoiceLine__c (child of Invoice__c via InvoiceLine__c.Invoice__c)
3. Invoice__c
4. (Account deletion TBD)

### Key Notes
- Use **Set Variable** immediately after each Salesforce Query to save IDs — the payload is overwritten by the next operation
- Salesforce Delete accepts a list of IDs — use Transform Message to extract IDs from query results before passing to Delete
- For Each Collection field can be left empty — defaults to `#[payload]`

### On New or Updated File Settings
- Directory: `C:\data\`
- File Name Pattern (Matcher): `AccountDeletes.csv`
- Min Size: `1` (do not leave as 0 — it will only pick up empty files)
- Polling interval: `10` seconds

### Transform Message (CSV → Java)
```
%dw 2.0
output application/java
---
payload
```

### Logger (for testing)
Inside the For Each, set Logger message to `#[payload.CompanyName]` to verify CSV is being read correctly.

---

## 2. Load Flow — CSV to Salesforce (Planned)

Loading order matters — parent objects must be created before child objects that reference them.

### Load Order
1. Account
2. Address__c (foreign key: Account__c → Account.Id)
3. Other child objects TBD

### Data Source Options
- **Short term:** CSV files exported from Access (`C:\data\`)
- **Medium term:** PostgreSQL (once installed) — business rules implemented in SQL queries

### Flow Structure (per object)
```
On New or Updated File
  → Transform Message (map CSV columns to Salesforce fields)
  → Salesforce Create
  → Logger
```

### Business Rules Approach
- Heavy filtering and validation done in PostgreSQL SQL queries
- Mule flow handles orchestration (sequencing, error handling)
- For CSV approach, basic filtering can be done in DataWeave

---

## DataWeave Reference

### Log payload as JSON
```
#[output application/json --- payload]
```

### Access a field from current payload
```
#[payload.CompanyName]
```

### Reference a stored variable
```
#[vars.accountId]
```
