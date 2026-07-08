# Flow Designs

## 0. Source Data Pipeline (Client Files → Access → CSV Export)

Upstream of every Mule flow in this file: how the client's raw data becomes the CSVs the flows actually read. Two distinct legs, in and out of Access — don't conflate their formats:

### Incoming leg — client files → Access
The client's **initial** data delivery (covering all work units — Jewelry, Petroleum, BiWeekly) was one `.xlsx` file per source table, each with a header row. **Going forward**, incoming files arrive as **`.unl`, pipe-delimited, no header row** instead — same column shape as the originals otherwise. This only affects how these files get imported into Access; it does not touch the Mule-facing CSVs (see outgoing leg below).

Since the `.unl` files have no header row, importing them requires a reheadering step:
1. ~~Open the `.unl` file in Excel (pipe-delimited).~~
2. ~~Add the column names back, matching the original (headered) source file for that table.~~
3. ~~Add a `SourceFileType` column, hardcoded per source file (not derived from any column in the data) — e.g. `"Current"` for `LaborStd`, `"Historical"` for `LaborStdHis`.~~
4. ~~Save as `.xlsx`.~~

Steps 1-4 (manual Excel reheadering) are superseded for LaborStd by the **`ImportSourceData`** Mule flow — see subsection below. It reads the raw pipe-delimited files directly, assigns column names positionally, adds `SourceFileType`, and writes the combined result as `.csv` (not `.xlsx` — CSV avoids the memory overhead of building an xlsx workbook in memory, see note below). This is what section 2 refers to as the `SourceFileType` column distinguishing merged Current/Historical records once these land in the combined `LaborStd`/`LaborAR` Access tables.

5. Import the resulting `.csv` into a **`_raw` staging table** (e.g. `LaborStd_raw`), not the final table directly — the final table (e.g. `LaborStd`) has an AutoNumber (counter) primary key field, which a direct import can't populate/reconcile against.
6. Run an append query to copy rows from the `_raw` staging table into the final table (e.g. `LaborStd_raw` → `LaborStd`), letting Access assign the AutoNumber key as rows are appended.

### `ImportSourceData` flow — automated reheadering (LaborStd)
Reads the two raw pipe-delimited LaborStd files, tags each with the right `SourceFileType`, combines them, and writes one `.csv` — replacing manual steps 1-4 above.

**Why CSV and not xlsx**: the first version of this flow output xlsx and threw `OutOfMemoryError: Java heap space` on a 14MB/200KB input pair — not a data-volume problem, but because the underlying POI library builds the whole xlsx workbook as an in-memory object tree (every cell/row/style as a Java object), which commonly balloons far past the raw file size, easily exceeding Studio's default embedded-runtime heap. DataWeave's CSV writer has no such overhead. Since Access can import `.csv` just as easily as `.xlsx`, there was no reason to keep fighting the xlsx writer.

**Source files** (pipe-delimited, no header row):
| File | SourceFileType |
|---|---|
| `laborstd.txt` | `Current` |
| `his_lab.txt` | `Historical` |

**Column order** — same 30 columns as the `labor_std.csv` Column Reference in section 2 (Index 1-30, `fein` → `batchid`), minus `id` (Access-assigned AutoNumber, not present in the raw file) and minus `SourceFileType` (added by this flow, not present in the raw file).

**Trigger**: `On New or Updated File`, same pattern as `LoadReadyFlag.csv` in section 2 — an Access form button writes a sentinel file once `laborstd.txt`/`his_lab.txt` are both in place, and that arrival starts the flow. Simpler for you to fire from an Access button than an HTTP call.

### On New or Updated File Settings
- Directory: `C:\data\`
- File Name Pattern (Matcher): `SourceDataReadyFlag.csv`
- Min Size: `1` (same reason as `LoadReadyFlag.csv` — `0` only picks up empty files; the flag file needs at least a byte of real content, e.g. a timestamp, not a zero-byte touch file)
- Polling interval: `10` seconds

Since the trigger event's payload is `SourceDataReadyFlag.csv` itself, not the data files, the flow starts with explicit **File Read** operations for both `.txt` files rather than relying on the trigger payload (same reasoning as `LoadReadyFlag.csv` in section 2).

**File paths** — everything in the same `C:\data\` folder the Salesforce load flow already polls. Output is named `LaborStd_raw.csv`, **not** `LaborStd.csv` — that name is already taken by the Salesforce load flow's poller (section 2), and this file has different contents anyway (it's the reheadered import feed for the `LaborStd_raw` staging table, not the finished Access export):
- Read: `C:\data\laborstd.txt`, `C:\data\his_lab.txt`
- Write: `C:\data\LaborStd_raw.csv`

**Flow Structure (Studio build steps):**
```
Flow: ImportSourceData
On New or Updated File (C:\data\, SourceDataReadyFlag.csv)

File Read (Path: C:\data\laborstd.txt)
  → On the Transform Message step's **Input** panel, explicitly define metadata for `payload` as CSV with `header: false`, `separator: "|"` — a `.txt` extension doesn't auto-detect as CSV the way `.csv` does, so without this the payload arrives as a raw String and `map` throws "expects Array, got String" (hit this during testing). Once defined, Studio parses each row into an object with generic keys (`column_0`, `column_1`, ...).
  → Set Variable: sourceFileType = "Current"
  → Transform Message (transform-laborstd-raw-name.dwl — operates on `payload` directly, now a pre-parsed Array; assigns the 30 real column names positionally via `row pluck $`, which reads values in column order regardless of the generic `column_N` keys Studio assigned; appends SourceFileType from vars.sourceFileType)
  → Set Variable: currentRows = payload

File Read (Path: C:\data\his_lab.txt)
  → Set Variable: sourceFileType = "Historical"
  → Transform Message (transform-laborstd-raw-name.dwl — same transform, reused; SourceFileType comes out "Historical" this time since it reads vars.sourceFileType)
  → Set Variable: historicalRows = payload

Transform Message (transform-laborstd-combine-export.dwl — vars.currentRows ++ vars.historicalRows, output application/csv)
File Write (Path: C:\data\LaborStd_raw.csv)

File Move: C:\data\laborstd.txt → C:\data\processed\
File Move: C:\data\his_lab.txt → C:\data\processed\
```
Archived last, same convention and reasoning as `LaborStd.csv`/`LaborAR.csv` in section 2 — if the flow errors out partway, the raw files are still sitting in `C:\data\` for investigation/retry rather than already relocated.

### Combine + Load Process (per work unit)
1. Current and historical datasets for a given table (e.g. `LaborStd` + `HisLaborStd`) are combined and loaded into Access, with `SourceFileType` (`Current` or `Historical`) set per source table as part of the load.

### Outgoing leg — Access → Mule flow folder
2. An Access form has one **export button per work unit** (currently only Jewelry exists) that dumps the relevant tables to **CSV** (unchanged format — still comma-delimited with a header row, matching section 2's Reader Configuration) in the folder the Anypoint flow polls. For Jewelry, the button exports `LaborStd.csv`, then `LaborAR.csv`, then the `LoadReadyFlag.csv` sentinel last (order matters — see section 2's Trigger File notes on why the flag file is written only once both data files are fully in place).
3. A separate button on the same form generates `AccountDeletes.csv` (see section 1). The delete flow's Salesforce-side logic is generic across work units — only the Access query that produces the company-name list changes. Currently there's one button/query; **planned improvement**: split into one button + one query per work unit (Jewelry/Petroleum/BiWeekly) rather than one query that has to be edited per run, to make testing each work unit independently easier.

---

## 1. Delete Flow — Remove Records by Company Name

Reads a CSV of company names and deletes all related Salesforce records in the correct order (children before parents).

### Trigger File
`C:\data\AccountDeletes.csv` — one column: `CompanyName`

### Flow Structure
```
On New or Updated File (C:\data\, AccountDeletes.csv)
  → Transform Message (parse CSV to Java list)
  → For Each (loop over company names)
      → Set Variable (companyName = #[payload.CompanyName replace "'" with "\\'"])
      → Salesforce Query: SELECT Id FROM Account WHERE Name = ':companyName'
          (Parameters: #[{companyName: vars.companyName}])
      → Set Variable (accountId = payload[0].Id)
      → Salesforce Query: SELECT Id FROM Invoice__c WHERE Account__c = :accountId
          (Parameters: #[{accountId: vars.accountId}])
      → For Each (loop over invoices)
          → Set Variable (invoiceId)
          → Salesforce Query: SELECT Id FROM Payment__c WHERE Invoice__c = :invoiceId
              (Parameters: #[{invoiceId: vars.invoiceId}])
          → Salesforce Delete (Payment__c)
          → Salesforce Query: SELECT Id FROM InvoiceLine__c WHERE Invoice__c = :invoiceId
              (Parameters: #[{invoiceId: vars.invoiceId}])
          → Salesforce Delete (InvoiceLine__c)
          → Salesforce Delete (Invoice__c)
  → Logger
```

### Delete Order (Important — children must be deleted before parents)
1. Payment__c (child of Invoice__c via Payment__c.Invoice__c)
2. InvoiceLine__c (child of Invoice__c via InvoiceLine__c.Invoice__c)
3. Invoice__c
4. Address__c (child of Location via Address__c.ParentId)
5. Location (TODO: add to delete flow)
6. Account_Status__c (child of Account via Account_Status__c.Account__c) — added to delete flow
7. Entity_Identifier__c (child of Account) — added to delete flow. Not created by the Mule load flow at all — it's auto-created by a Salesforce trigger (off Account creation, presumably), so it never appeared anywhere in the load design, but still needs cleanup on delete since it's still a real child record of Account
8. (Account deletion TBD)

### Key Notes
- Use **Set Variable** immediately after each Salesforce Query to save IDs — the payload is overwritten by the next operation
- Salesforce Delete accepts a list of IDs — use Transform Message to extract IDs from query results before passing to Delete
- For Each Collection field can be left empty — defaults to `#[payload]`
- **Mule's `For Each` scope has no built-in per-item variable** — its only configurable fields are Collection, Batch Size, Counter Variable Name, and Root Message Variable Name. The current item just *becomes* `payload` for that iteration. Anywhere this project references `vars.row`, that only works because of an explicit `Set Variable: row = #[payload]` as the very first step inside the loop — add it manually every time, it won't happen on its own. (Bit us once in `AddInvoices` where this step was missing — everything off `vars.row` silently evaluated to null.)
- After Salesforce Create, the ID is at: `#[payload.items[0].payload.id]`
- Salesforce Create Records field: single-object transforms use `#[[payload]]`; list-returning transforms (e.g. Contact) use `#[payload]`
- **Salesforce Query bind parameters are substituted literally — no auto-quoting, no auto-escaping.** Verified empirically: dropping the quotes (`Name = :companyName`) produced `Name = Global Casting USA Inc` on the wire — an unquoted multi-word literal, not a properly quoted string. The connector does not add quotes for String parameters.
  - Keep the quotes in the query template: `Name = ':companyName'`
  - For any bound value that's free text (not a Salesforce Id), escape apostrophes yourself before binding: `#[value replace "'" with "\\'"]` — otherwise a name like `Three A's Polishiing` breaks the string literal and throws an invalid-request-data fault.
  - IDs (`accountId`, `invoiceId`, etc.) never need this — they're alphanumeric only.
  - **Escape in place vs. keep a separate variable** — depends on how many times the value is used downstream. In the delete flow, the company name is consumed exactly once (this lookup query) and never referenced again, so it's fine to escape it directly in the same Set Variable that holds it. Contrast with the load flow's `Account.Name`, which feeds the Create payload, the CSV log, etc. — there, escaping in place would corrupt the real data, so any query-bound escaping must go into its own separate variable, never overwriting the source value.

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

## 2. Combined Load Flow — CSV to Salesforce (labor_std + labor_ar)

### Work Units
The Jewelry work unit has two source files, both exported as CSV from Access:

| File | Description |
|---|---|
| `LaborStd.csv` | Combined current + historical labor records (labor_std and his_labor_std merged) |
| `LaborAR.csv` | Combined current + historical accounts receivable / invoice data (labor_ar and his_labor_ar merged) |

Both files include a `SourceFileType` column (`Current` or `Historical`) to distinguish the merged records.

### Processed File Archiving
After the whole combined flow completes (including the `import_log.csv` write), `LaborStd.csv` and `LaborAR.csv` are moved to `C:\data\processed\` via File Move operations — one per file, at the very end of the flow. Moved last (not right after each File Read) so that if the flow errors out partway through, the source files are still sitting in `C:\data\` for investigation/retry rather than already relocated.

### Trigger File — `LoadReadyFlag.csv`
Rather than triggering on `LaborStd.csv` arrival directly, the flow triggers on a **sentinel file**, `LoadReadyFlag.csv`, created manually only after `LaborStd.csv` and `LaborAR.csv` are both fully in place in `C:\data\`. This avoids two race conditions: the poller picking up a data file mid-copy, and the labor_ar half of this flow running before the labor_std half has finished (they're now one combined flow — see below — but the trigger file still has to reflect "all inputs are ready" before anything starts).

**TODO**: rename to `LoadReadyFlagJewelry.csv` — now that Petroleum has its own trigger file (`LoadReadyFlagPetroleum.csv`, see section 6), Jewelry's should follow the same `LoadReadyFlag<WorkUnit>.csv` convention instead of being the unqualified original name. Update the Access export button and this flow's File Name Pattern together when this happens.

**The flag file cannot be empty.** `Min Size` must stay at `1` (established earlier — `Min Size: 0` causes the poller to only pick up empty files), so `LoadReadyFlag.csv` needs at least a byte of real content (e.g. a timestamp), not a zero-byte touch file.

Since the trigger event's payload is `LoadReadyFlag.csv` itself, not the data files, the flow starts with explicit **File Read** operations for both CSVs rather than relying on the trigger payload.

### On New or Updated File Settings
- Directory: `C:\data\`
- File Name Pattern (Matcher): `LoadReadyFlag.csv`
- Min Size: `1`
- Polling interval: `10` seconds

### Load Order (within labor_std.csv flow)
1. Account
2. Location (1 or 2 — see Mailing/Physical rule below)
3. Address__c (one per Location, ParentId = Location Id)
4. PartyAddress__c (junction — links Account to Address, one per Address)
5. Contact (one per non-null respparty, up to 4)
6. Business License Application
7. Business License
8. Assessment
9. Assessment Question Response

### Sub-Flow Architecture (Studio)
The combined flow is implemented as a main flow calling out to named sub-flows via Flow Reference, rather than one flat flow body:

| Sub-Flow | Responsibility |
|---|---|
| `InitAssessmentQuestionVersion` | Runs once (not per-row) — builds `vars.aqvMap`, the AssessmentQuestionVersion lookup used later by Assessment Question Response (`transform-aqv-lookup.dwl`) |
| `InitAccountRecordType` | Runs once (not per-row) — queries the Account Record Type Id by `DeveloperName` (stable across sandbox refreshes, unlike a hardcoded Id) and sets `vars.accountRecordTypeId`, used by `transform2-account.dwl` |
| `AddAccount` | Salesforce Create Account, Result & Log Pattern; sets `accountId`. If `accountId != null`, also Choice-gated creates one Account_Status__c (filters the pre-parsed `vars.arRows` to this row's jobno, takes the oldest `deposit_date` — see section 5) |
| `AddLocationsAndAddresses` | Location(s) → per-location Choice-gated Address__c → PartyAddress__c (see Flow Structure below) |
| `AddContacts` | Contact list create (0-4), List Result & Log Pattern; independent, no gating |
| `AddBusinessLicenseApp` | BLA → Choice-gated Business License / Assessment / Assessment Question Response chain; sets `blaId`, appends to `blaJobnoLog` |
| `AddSentInvoice` | Called **after `AddInvoices` completes**, once per Current-sourced BLA (`blaJobnoLog` filtered on `sourceFileType == "Current"`) — must run last so the Salesforce trigger marks this as the "Active" invoice on the BLA. Creates one Invoice__c (`InvoiceStatus__c: "Sent"`) + InvoiceLine__c per cutover account, no Payment__c (see section 4) |
| `AddInvoices` | Invoice Load — called once, processing `LaborAR.csv` rows via `vars.blaJobnoLog` lookup → Invoice__c → Choice-gated InvoiceLine__c/Payment__c (see section 3) |

`InitAssessmentQuestionVersion` and `InitAccountRecordType` both run once at the start of the flow (before the labor_std `For Each`); the other sub-flows are called per-row (or, for `AddInvoices`, per-file) from within the relevant loop.

### InitAccountRecordType (sub-flow body)
```
Salesforce Query: SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account'
Set Variable: accountRecordTypeId = #[payload[0].Id]
```
`DeveloperName` is a fixed constant known at design time (not row data), so it's embedded directly in the query text rather than bound as a parameter — the "never manually quote a bind parameter" rule (see Key Notes in section 1) only applies to values built from row/user data, not literals like this.

**Why this exists**: a hardcoded `RecordTypeId` broke after a sandbox refresh (refreshes regenerate Salesforce record Ids). `DeveloperName` stays stable across refreshes, so querying by it once at flow start makes the flow resilient — same reasoning as `InitAssessmentQuestionVersion`.

### Mailing / Physical Location Rule
If `add1` and `add2` are both non-null and one of them contains "PO Box", that one is the **Mailing** address and the other is the **Physical** address — two Location records are created (`transform-location.dwl`: `Name` = `"Mailing"` / `"Physical Location"`). Otherwise, a single `"Mailing"` Location is created covering the whole address.

**"P.O. Box" variant**: the source data has both `"PO Box"` and `"P.O. Box"` (periods) — a plain `contains "po box"` on the lowercased string misses the latter, since the periods break the substring match. Fix (in both `transform-location.dwl` and `transform-address.dwl`, which duplicate this same PO Box check): strip periods before matching — `(lower(add1) replace "." with "") contains "po box"`.

`Address_Type__c` (picklist on Address__c / PartyAddress__c) only accepts `"Mailing"` / `"Physical"` — **not** `"Physical Location"`. The Location's `Name` field keeps the fuller phrase for readability, but the `addressType` variable driving Address__c/PartyAddress__c creation must be normalized to `"Physical"` (see Flow Structure below — this is a derived value, not a direct copy of `Location.Name`).

Invoice, Invoice Line, and Payment load from `LaborAR.csv` after the labor_std portion of this same flow execution completes — see Flow Structure below.

### Column Reference (labor_std.csv)
Columns now parse directly into named fields via the CSV header (`header: true`) — the "Index" column below is just for reference (original Access export order), not used for positional access anymore.

| Index | Column | Notes |
|---|---|---|
| 0 | id | Access surrogate key |
| 1 | fein | |
| 2 | recnumb | |
| 3 | appnumb | |
| 4 | name | → Account Name |
| 5 | legalcode | |
| 6 | bustype | |
| 7 | zip | → BillingPostalCode |
| 8 | sic | |
| 9 | predacc | |
| 10 | acc | |
| 11 | add1 | → BillingStreet line 1 |
| 12 | add2 | → BillingStreet line 2 |
| 13 | city | → BillingCity |
| 14 | state | → BillingState |
| 15 | change_of_addr | |
| 16 | date_changed | |
| 17 | out_of_business | |
| 18 | company | |
| 19 | respparty1 | → Contact 1 |
| 20 | title1 | → Contact 1 Title |
| 21 | respparty2 | → Contact 2 |
| 22 | title2 | → Contact 2 Title |
| 23 | respparty3 | → Contact 3 |
| 24 | title3 | → Contact 3 Title |
| 25 | respparty4 | → Contact 4 |
| 26 | title4 | → Contact 4 Title |
| 27 | jobno | |
| 28 | issue_date | |
| 29 | tot_pymt | |
| 30 | batchid | |
| 31 | SourceFileType | `Current` or `Historical` |

### Result & Log Pattern (used after every Salesforce Create below)
No explicit `Set Variable: logEntries = []` (or `blaJobnoLog = []`) initialization is needed before first use — every append already does `(vars.logEntries default []) ++ [...]`, and referencing an unset flow variable in DataWeave evaluates to `null`, not an error, so `null default []` resolves to `[]` on the very first append.

Salesforce validation failures (duplicate rule, required field, malformed data) do **not** throw a Mule error — the connector call still "succeeds," and the failure shows up per-record in the response payload. So every Create is followed by an extraction step, not a Try/On Error Continue (that's reserved for genuine pre-Salesforce failures, e.g. a DataWeave date-coercion error — wrap the Transform+Create pair in Try/On Error Continue for those, and treat the caught error the same as a failed extraction below):
```
Transform Message: extract result
  var result = payload.items[0]
  ---
  {
      success: result.exception == null,
      id: if (result.exception == null) result.payload.id else null,
      errorCode: if (result.exception != null) result.exception.statusCode else null,
      errorMessage: if (result.exception != null) result.exception.message else null
  }
Set Variable: <thing>Result = payload
Set Variable: <thing>Id = vars.<thing>Result.id
Set Variable: logEntries = (vars.logEntries default []) ++ [{
    jobno: vars.row.jobno,
    object: "<ObjectName>",
    status: if (vars.<thing>Result.success) "Success" else "Failed",
    salesforce_id: vars.<thing>Id,
    error_code: vars.<thing>Result.errorCode,
    error_message: vars.<thing>Result.errorMessage
}]
```

**List variant** — for transforms that create multiple records in one Create call (Location, Contact, Assessment Question Response). Use `Records: #[payload]` (not `#[[payload]]` — the transform output is already a list) on the Create step itself:
```
Transform Message: extract results
  payload.items map (item) -> {
      success: item.exception == null,
      id: if (item.exception == null) item.payload.id else null,
      errorCode: if (item.exception != null) item.exception.statusCode else null,
      errorMessage: if (item.exception != null) item.exception.message else null
  }
Set Variable: <thing>Results = payload
Set Variable: logEntries = (vars.logEntries default []) ++ (vars.<thing>Results map (r) -> {
    jobno: vars.row.jobno,
    object: "<ObjectName>",
    status: if (r.success) "Success" else "Failed",
    salesforce_id: r.id,
    error_code: r.errorCode,
    error_message: r.errorMessage
})
```

### Dependency Rules (gate downstream Creates with a Choice on the parent's Id)
- **BLA required for**: Business License, Assessment, Assessment Question Response, and (later) Invoice → Invoice Line/Payment. If BLA fails, skip all of these for that row.
- **Location required for**: Address__c, PartyAddress__c — gated per location item (Location is a batch create of 1-2 items; one can fail while the other succeeds).
- **Contacts are independent** — log success/failure per contact; nothing downstream depends on them, no gating.

### Flow Structure (combined — triggered by LoadReadyFlag.csv)
Sub-flow boundaries noted inline — see Sub-Flow Architecture above for what each contains.
```
On New or Updated File (C:\data\, LoadReadyFlag.csv)
  → File Read: C:\data\LaborStd.csv
  → Transform Message (transform1-filter-and-name.dwl — operates directly on payload straight from the Read, no intermediate raw variable; CSV → Java, header: true; filters invalid rows and cleans jobno, columns already named from header)
  → Set Variable: laborStdRows = #[payload]
  → File Read: C:\data\LaborAR.csv
  → Transform Message (transform-ar-filter-and-name.dwl — operates directly on payload straight from the Read, no intermediate raw variable, same pattern as LaborStd.csv above; filters invalid rows, cleans jobno, sorts by deposit_date ascending)
  → Set Variable: arRows = #[payload] (reused by both AddAccount, per-row filtered by jobno, and AddInvoices, iterated whole — parsing once here instead of twice)
  → Flow Reference: InitAssessmentQuestionVersion (runs once — sets vars.aqvMap)
  → Flow Reference: InitAccountRecordType (runs once — sets vars.accountRecordTypeId)
  → For Each row: (Collection: #[vars.laborStdRows])
      → Set Variable: row = #[payload] (Mule's For Each has no built-in per-item variable — the current item IS payload for that iteration, so this converts it into vars.row for everything downstream to reference)
      → Flow Reference: AddAccount
          → Salesforce Create Account (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Account"]
          → Choice
              When #[vars.accountId != null]:
                  → Transform Message (transform-account-status.dwl — filters the pre-parsed vars.arRows to rows matching vars.row.jobno, takes the oldest deposit_date among them; see section 5)
                  → Salesforce Create Account_Status__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Account_Status__c"]
              Otherwise: (skip — Account failed, Account_Status__c not attempted)
      → Flow Reference: AddLocationsAndAddresses
          → Transform Message: build location array (transform-location.dwl — 1 or 2 items)
          → Set Variable: locationList = payload   (save before Create overwrites it)
          → Salesforce Create Location(s): Records = vars.locationList
          → Transform Message (transform-location-results.dwl — pairs Create response Ids back to type + success/error, by index)
          → Set Variable: locationResults = payload
          → For Each (Collection: #[vars.locationResults]):
              → Set Variable (locationId = #[payload.locationId])
              → Set Variable (addressType = #[payload.addressType])
              → Set Variable: logEntries = (vars.logEntries default []) ++ [{ jobno: vars.row.jobno, object: "Location", status: if (payload.success) "Success" else "Failed", salesforce_id: vars.locationId, error_code: payload.errorCode, error_message: payload.errorMessage }]
              → Choice
                  When #[vars.locationId != null]:
                      → Transform Message (transform-address.dwl) → Salesforce Create Address__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Address__c"; sets addressId]
                      → Choice
                          When #[vars.addressId != null]:
                              → Transform Message (transform-partyaddress.dwl) → Salesforce Create PartyAddress__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "PartyAddress__c"]
                          Otherwise: (skip — Address failed)
                  Otherwise: (skip — Location failed, Address/PartyAddress not attempted)
      → Flow Reference: AddContacts
          → Transform Message (transform-contact.dwl — builds list of 0-4 Contacts, nulls for empty respparty already filtered out)
          → Salesforce Create Contact (Records: #[payload]) → [List Result & Log Pattern → logEntries, object: "Contact"] (independent — no gating; Contact ids not referenced downstream)
      → Flow Reference: AddBusinessLicenseApp
          → Salesforce Create Business License Application (AccountId = accountId, Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "BusinessLicenseApplication"; sets blaId]
          → Choice
              When #[vars.blaId != null]:
                  → Set Variable: blaJobnoLog = (vars.blaJobnoLog default []) ++ [{ jobno: vars.row.jobno, blaId: vars.blaId, accountId: vars.accountId, sourceFileType: vars.row.SourceFileType }]
                  → Salesforce Create Business License (linked to blaId, Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "BusinessLicense"]
                  → Salesforce Create Assessment (linked to blaId, Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Assessment"; sets assessmentId]
                  → Transform Message (transform-assessment-question-response.dwl — uses vars.assessmentId, vars.aqvMap; builds list of 7)
                  → Salesforce Create Assessment Question Response (Records: #[payload]) → [List Result & Log Pattern → logEntries, object: "AssessmentQuestionResponse"]
              Otherwise: (skip — BLA failed, BL/Assessment/AQR not attempted)
  → File Write: C:\data\bla_jobno_map.csv (overwrite, content = vars.blaJobnoLog as CSV — debug/audit artifact; the labor_ar join below uses vars.blaJobnoLog directly in memory, no read-back needed)

  → Flow Reference: AddInvoices (no input needed — reads vars.arRows directly)
      (see "3. Invoice Load" below for what AddInvoices does — For Each row over the given raw CSV, join to vars.blaJobnoLog by jobno, Choice-gated Invoice__c → InvoiceLine__c/Payment__c)

  → Flow Reference: AddSentInvoice (see section 4 — self-contained: filters vars.blaJobnoLog to Current-sourced accounts and loops internally, creating Invoice__c "Sent" + InvoiceLine__c per account, no Payment__c)
      (Runs after AddInvoices completes entirely, so every AR-driven invoice for every BLA already exists — this is what makes each account's Sent invoice the most recently created one, which is what the Salesforce trigger uses to mark it "Active" on the BLA)

  → File Write: C:\data\import_log.csv (overwrite, content = vars.logEntries as CSV — single write covering the whole combined run; column order: jobno, object, status, salesforce_id, error_code, error_message, matching import_log table minus id/logged_at)
  → File Move: C:\data\LaborStd.csv → C:\data\processed\
  → File Move: C:\data\LaborAR.csv → C:\data\processed\
```

### Reader Configuration (Transform Message)
- Input MIME type: `application/csv`
- `header: true` — the source CSVs' header row already matches the field names used throughout the transforms (`jobno`, `add1`, `respparty1`, etc. — see Column Reference tables below), so rows parse directly into named objects. This means `transform1-filter-and-name.dwl` / `transform-ar-filter-and-name.dwl` no longer need to map positional columns to field names — they just filter invalid rows and clean up `jobno` (see below).
- One exception: the source column is `ID`, not `id` — `transform1-filter-and-name.dwl` renames it (`(row - "ID") ++ { id: row.ID, ... }`) since that's cheaper than changing the file export.

### Key Design Decisions
- **Create not Upsert** — flows are one-time cutover imports; re-runs use the delete flow to clear data first, so no external ID fields are needed
- **BillingStreet** — confirm whether add1 and add2 concatenate into one field or map to separate custom fields

### BLA ↔ jobno Mapping (`vars.blaJobnoLog`)
Invoice data (`LaborAR.csv`) is keyed by jobno but needs the Salesforce BLA Id to link Invoice__c records back to the right Business License Application. Since the labor_std and labor_ar processing are now one combined flow execution (triggered by `LoadReadyFlag.csv`), this is a straightforward in-memory handoff — no file round-trip needed for the join itself:

- Accumulate pairs in a flow variable (`blaJobnoLog`) as each row's BLA is created — **not** a File Write per iteration, which would be far slower (file open/close on every row vs. once for the whole run)
- After the labor_std `For Each` completes, also write the accumulated list to `C:\data\bla_jobno_map.csv` (DataWeave `output application/csv` — includes header row `jobno,blaId,accountId` by default) — kept purely as a debugging/audit artifact, since it's no longer read back by anything
- Append the pair immediately after `blaId` is set (not at the end of the row's processing), so a valid mapping is still captured even if a later step (Assessment, AQR, etc.) fails for that row

The Invoice Load (below) references `vars.blaJobnoLog` directly and joins on jobno.

### TODO
- ~~Delete Account_Status__c in the RemoveAccounts (Delete) flow~~ — done, and Entity_Identifier__c (a trigger-created child of Account, not part of the load flow) added alongside it. See Delete Order in section 1, items 6-7.
- **Implement invoice date ordering in Studio** — designed (see Load Order under section 3: `transform-ar-filter-and-name.dwl`'s `orderBy` on `deposit_date`, oldest first), but not yet built/applied in the actual Studio project.
- **Go back and apply the Result & Log Pattern to the other subflows in Studio** — `AddInvoices` is getting it built-in now; `AddAccount`, `AddLocationsAndAddresses`, `AddContacts`, `AddBusinessLicenseApp` were built earlier and need to be revisited to confirm every Salesforce Create in them actually has the extract-result + `logEntries` append steps wired up, matching what's documented in Flow Structure above (design is correct in the doc — needs verifying against the actual Studio build).
- Build the Invoice Load Flow (see below) using `vars.blaJobnoLog` (in-memory, same flow execution — see Trigger File section above)
- **Interim reconciliation logging (current plan)**: write `import_log.csv` via the Result & Log Pattern (see above), then import into the Postgres `import_log` table using pgAdmin's **Import/Export Data** tool (right-click table → Import, point at the CSV, header: yes, map columns to jobno/object/status/salesforce_id/error_code/error_message, leave id/logged_at unmapped). This works entirely through pgAdmin's existing connection — no Mule Database connector or JDBC driver required, so it's unaffected by the Maven/PKIX blocker below.
- PostgreSQL reconciliation logging **directly from the Mule flow** — **blocked**: Maven can't resolve `org.postgresql:postgresql:42.7.3` (`PKIX path building failed` — the sandbox's TLS-intercepting proxy isn't trusted by Java's cacerts). Fix requires importing the corporate root CA into the JDK Studio bundles, which needs admin rights. Checking with IT. Revisit once unblocked — would replace the CSV/pgAdmin-import step above with direct Database Insert per log entry.
  - Add Database connector from Exchange to project
  - Add PostgreSQL JDBC driver to pom.xml (`org.postgresql:postgresql:42.7.3`)
  - Configure global Database Config (PostgreSQL Connection, localhost:5432)
  - Create `import_log` table (see DDL below)

### Business Rules Approach
- Business rules (filtering, field mapping, date formatting, address logic) handled in DataWeave transforms within the Mule flows
- Access/PostgreSQL SQL queries used for data extraction only

---

## 3. Invoice Load — `AddInvoices` sub-flow

Loads Invoice__c / InvoiceLine__c / Payment__c from `LaborAR.csv`, joined to the BLA Id captured during the labor_std portion of the same flow execution (see "2. Combined Load Flow" above — triggered once by `LoadReadyFlag.csv`). Called once via Flow Reference, no input needed — reads `vars.arRows`, which is parsed once upfront in the main flow (see Sub-Flow Architecture above and section 2's Flow Structure).

### Grain
Confirmed: **1 row = 1 Invoice__c = 1 InvoiceLine__c = 1 Payment__c.** `jobno` is not unique within `LaborAR.csv` — the same job can have multiple invoices (e.g. job `1996350007` has 4 same-day deposits, see `dev-questions.md` #5) — but that doesn't change the grain, it just means the jobno→blaId/accountId lookup can match multiple rows to the same BLA, which is expected.

### Load Order
Invoices load oldest-first, sorted by `deposit_date` (not the pymt_type-derived date) — added as an `orderBy` at the end of `transform-ar-filter-and-name.dwl`'s filter/map chain: `orderBy (row) -> ... row.deposit_date as Date {format: "M/d/yyyy"} ...`. Rows with a blank `deposit_date` sort to the very front (fallback key `|0001-01-01|`) rather than throwing on the `Date` coercion — worth spot-checking during testing whether any rows actually hit that fallback, since it'd mean bad/missing data rather than a real oldest invoice. The `filter`→`map` chain is wrapped in its own parens before `orderBy` is chained on, same defensive pattern as the `filter`/`map` entanglement gotcha in the DataWeave Reference section.

### pymt_type Discriminator
`pymt_type` selects which set of payment-method fields is populated, and drives multiple downstream field values:

| pymt_type | Meaning | Date field used | Reference # field used | Payment_Method__c |
|---|---|---|---|---|
| `K` | Check | `check_date` | `check_no` | `"Check"` |
| `C` | Cash | `cash_pymt_date` | `cash_recpt_no` | `"Cash"` |
| `M` | Money Order | `mo_ord_date` | `mo_ord_no` | `"Money Order"` |

### Date Format
`LaborAR.csv` date fields (`check_date`, `cash_pymt_date`, `mo_ord_date`, `deposit_date`) come through as `M/d/yyyy` — non-padded month/day (e.g. `1/1/2026`, `10/1/2025`, `1/10/2025`) — **not** `MM/dd/yyyy` like `labor_std.csv`'s `issue_date`. Root cause: these Access columns were originally typed as Date/Time, which appended a `0:00:00` time component on CSV export (caused a real coercion error: `Text '8/23/2016 0:00:00'` failing against `MM/dd/yyyy`); fixed at the source by retyping the Access columns to Short Text before export, so the time component is gone but the month/day are still non-padded. All date parsing in `transform-invoice.dwl` and `transform-payment.dwl` uses `Date {format: "M/d/yyyy"}` accordingly — don't copy the `MM/dd/yyyy` pattern from the labor_std transforms into new AR-side code, and if a future Access export re-adds Date/Time typing, watch for this same issue resurfacing.

**Output type — `Date`, not `String`.** `DueDate__c`/`InvoiceDate__c`/`PaymentDate__c`/`ReceiptDate__c` are Salesforce **Date** fields, and the connector rejects a `String` even when it's valid ISO format (`"2016-08-23"`) — confirmed via a real error: `value not of required type: 2016-08-23`. Fix: stop at `... as Date {format: "M/d/yyyy"}` and do **not** chain a further `as String {format: "yyyy-MM-dd"}` — leave the value as DataWeave's `Date` type and let the connector serialize it. This is different from the DateTime fields elsewhere in the project (BLA's `AppliedDate`, Assessment's `EffectiveDateTime`), which need a full ISO8601 `String` with a time/timezone component, not a bare `Date`.

**Recurring pattern — Access numeric columns export with a trailing `.00`.** Same root cause as the `jobno` decimal artifact (`transform1-filter-and-name.dwl`/`transform-ar-filter-and-name.dwl`), hit a second time on `Payment__c.ReferenceNumber__c` (sourced from `cash_recpt_no`/`mo_ord_no`, both Access numeric columns). Fix is the same each time: `(value default "" splitBy ".")[0]` to strip everything after the decimal point. Check any *other* field sourced from a numeric-typed Access column for this before assuming it's clean — it's cheap to apply defensively even where it turns out to be a no-op.

### Field Mapping

**Invoice__c** (`transform-invoice.dwl`)
| Field | Source |
|---|---|
| Account__c | `vars.accountId` (from jobno lookup — see below) |
| BusinessLicenseApplication__c | `vars.blaId` (from jobno lookup) |
| DueDate__c | `deposit_date`, parsed to DataWeave `Date` type |
| InvoiceDate__c | date field per pymt_type table above, parsed to DataWeave `Date` type |
| InvoiceStatus__c | hardcoded `"Paid"` |

**InvoiceLine__c** (`transform-invoiceline.dwl`)
| Field | Source |
|---|---|
| Invoice__c | `vars.invoiceId` |
| Quantity__c | hardcoded `1` |
| LineType__c | hardcoded `"Base Fee"` |
| ProrateFactor__c | hardcoded `100` |
| UnitPrice__c | `pymt_code_amt` (only — `refund_code_amt`/`misc_code_amt` are not currently loaded; confirm with dev team if that data matters) |

~~ReferenceNumber__c~~ — removed from InvoiceLine__c (field no longer exists / no longer required on this object; still present on Payment__c below).

**Payment__c** (`transform-payment.dwl`)
| Field | Source |
|---|---|
| BusinessLicenseApplication__c | `vars.blaId` |
| Invoice__c | `vars.invoiceId` |
| Amount__c | `pymt_code_amt` |
| PaymentDate__c | `deposit_date`, parsed to DataWeave `Date` type (same rule as DueDate__c) |
| Payment_Method__c | per pymt_type table above |
| Payment_Status__c | hardcoded `"Completed"` |
| ReceiptDate__c | `deposit_date`, parsed to DataWeave `Date` type (same as PaymentDate__c) |
| ReferenceNumber__c | reference # field per pymt_type table above, decimal-stripped (`.00` artifact — see Date Format section's numeric-column note) |

### Flow Structure (`AddInvoices` sub-flow body)
No re-parse needed here — `vars.arRows` was already computed once upfront (see section 2's Flow Structure), already filtered/cleaned/sorted oldest-first. `AddInvoices` just iterates over it directly:
```
For Each (Collection: #[vars.arRows]):
      → Set Variable: row = #[payload] (Mule's For Each has no built-in per-item variable — see note in section 2's Flow Structure)
      → Transform Message (transform-ar-lookup.dwl — finds {jobno, blaId, accountId} from vars.blaJobnoLog by jobno; {} if no match)
      → Set Variable: blaAccountLookup = payload
      → Set Variable: blaId = vars.blaAccountLookup.blaId
      → Set Variable: accountId = vars.blaAccountLookup.accountId
      → Choice
          When #[vars.blaId != null and vars.accountId != null]:
              → Transform Message (transform-invoice.dwl) → Salesforce Create Invoice__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Invoice__c"; sets invoiceId]
              → Choice
                  When #[vars.invoiceId != null]:
                      → Transform Message (transform-invoiceline.dwl) → Salesforce Create InvoiceLine__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "InvoiceLine__c"]
                      → Transform Message (transform-payment.dwl) → Salesforce Create Payment__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Payment__c"]
                  Otherwise: (skip — Invoice failed, InvoiceLine/Payment not attempted)
          Otherwise: (skip — no matching BLA/Account for this jobno; log as failure — see below)
```

Since a missing jobno match isn't a Salesforce Create failure (there's no `item.exception` to extract — the lookup itself came back empty), log it explicitly in the `Otherwise` branch of the outer Choice:
```
Set Variable: logEntries = (vars.logEntries default []) ++ [{
    jobno: vars.row.jobno, object: "Invoice__c", status: "Failed",
    salesforce_id: null, error_code: "NO_BLA_MATCH",
    error_message: "No matching BLA/Account found in blaJobnoLog for this jobno"
}]
```

### Column Reference (LaborAR.csv)
Columns parse directly into named fields via the CSV header (`header: true`) — the "Index" column below is just for reference, not used for positional access anymore.

| Index | Column | Notes |
|---|---|---|
| 0 | jobno | Same data type/format as labor_std.csv — join key to `vars.blaJobnoLog` (in-memory) |
| 1 | appnumb | number |
| 2 | pymt_code | text |
| 3 | pymt_code_amt | number — used for InvoiceLine__c.UnitPrice__c and Payment__c.Amount__c |
| 4 | refund_code | text — not currently loaded |
| 5 | refund_code_amt | number — not currently loaded |
| 6 | misc_code | text — not currently loaded |
| 7 | misc_code_amt | number — not currently loaded |
| 8 | misc_desc | text |
| 9 | pymt_type | text — discriminator: `K`=Check, `C`=Cash, `M`=Money Order (see pymt_type Discriminator table below) |
| 10 | check_date | date |
| 11 | check_no | text |
| 12 | bank_no | number |
| 13 | check_amt | number |
| 14 | bad_check_flag | text |
| 15 | mo_ord_no | number |
| 16 | mo_ord_date | date |
| 17 | mo_ord_amt | number |
| 18 | cash_recpt_no | number |
| 19 | cash_pymt_date | date |
| 20 | cash_amt | number |
| 21 | tot_pymt_amt | number |
| 22 | deposit_voucher | number |
| 23 | deposit_date | date |
| 24 | budget_acc1 | number |
| 25 | budget_acc2 | number |
| 26 | remarks | text |
| 27 | batchid | text |
| 28 | SourceFileType | `Current` or `Historical` |

### Open Questions
- ~~Grain, InvoiceLine__c mapping, Payment__c mapping, Salesforce field API names~~ — resolved, see Grain / pymt_type Discriminator / Field Mapping above.
- Dev question pending (`dev-questions.md` #5): job `1996350007` has 4 same-day deposits — confirmed this doesn't change the 1-row-per-invoice grain, but worth the dev team's sign-off in case same-day deposits should logically be one invoice.
- `refund_code_amt`/`misc_code_amt` aren't loaded — confirm with dev team whether that's acceptable or whether that data needs to land somewhere.
- Join strategy: a plain filter per row (`transform-ar-lookup.dwl`) is fine at this scale (~150 accounts) — no need for `groupBy` optimization.

---

## 4. Sent Invoice (Cutover) — `AddSentInvoice` sub-flow

For every account sourced from the **Current** portion of `LaborStd.csv` (`SourceFileType == "Current"`), the old system will send an invoice right before cutover that has no corresponding payment record in `LaborAR.csv` — so unlike the AR-driven invoices, this one gets Invoice__c + InvoiceLine__c only, no Payment__c, and a different status.

### Ordering constraint
**This must be the last invoice created for each BLA.** A Salesforce trigger marks whichever invoice was most recently created as the "Active" invoice on the BLA — so this sub-flow is deliberately called *after* `AddInvoices` finishes processing the entire `LaborAR.csv` file, not nested inside the labor_std loop where BLAs are created. Calling it earlier would let an AR-driven invoice created later "win" the Active flag instead.

To make this possible, `blaJobnoLog` entries now also capture `sourceFileType` (see section 2's Flow Structure) — after `AddInvoices` completes, the main flow filters `blaJobnoLog` down to `Current` entries and loops over just those, calling `AddSentInvoice` once per account.

### Field Mapping

**Invoice__c** (`transform-sent-invoice.dwl`) — all hardcoded except the two lookup Ids:
| Field | Source |
|---|---|
| Account__c | `vars.row.accountId` (from the filtered `blaJobnoLog` entry) |
| BusinessLicenseApplication__c | `vars.row.blaId` (from the filtered `blaJobnoLog` entry) |
| DueDate__c | hardcoded `9/30/2026` |
| InvoiceDate__c | hardcoded `8/1/2026` |
| InvoiceStatus__c | hardcoded `"Sent"` |

**InvoiceLine__c** (`transform-sent-invoiceline.dwl`):
| Field | Source |
|---|---|
| Invoice__c | `vars.sentInvoiceId` |
| Quantity__c | hardcoded `1` |
| LineType__c | hardcoded `"Base Fee"` |
| ProrateFactor__c | hardcoded `100` |
| UnitPrice__c | hardcoded `120` |

`Quantity__c`/`LineType__c`/`ProrateFactor__c` are carried over from the AR-side InvoiceLine convention (not separately specified) — confirm with the business if these should differ for the Sent invoice.

No Payment__c is created for this invoice.

### Flow Structure (`AddSentInvoice` sub-flow body)
Self-contained, same pattern as `AddInvoices` — the main flow just calls this once (no input needed; `vars.blaJobnoLog` persists automatically since it's a flow variable), and this sub-flow does its own filtering and looping:
```
Transform Message: filter blaJobnoLog to Current-sourced accounts only
    #[vars.blaJobnoLog filter (entry) -> entry.sourceFileType == "Current"]
Set Variable: currentAccounts = payload
For Each (Collection: #[vars.currentAccounts]):
    Set Variable: row = #[payload] (row = {jobno, blaId, accountId, sourceFileType} — not a labor_std CSV row; no need for separate blaId/accountId Set Variables, transform-sent-invoice.dwl reads vars.row.blaId/vars.row.accountId directly)
    Transform Message (transform-sent-invoice.dwl)
    Salesforce Create Invoice__c (Records: #[[payload]])
    Transform Message: extract result (single-item Result & Log Pattern)
    Set Variable: sentInvoiceResult = payload
    Set Variable: sentInvoiceId = vars.sentInvoiceResult.id
    Set Variable: logEntries append (object: "Invoice__c (Sent)")
    Choice
        When #[vars.sentInvoiceId != null]:
            Transform Message (transform-sent-invoiceline.dwl)
            Salesforce Create InvoiceLine__c (Records: #[[payload]])
            Transform Message: extract result (single-item pattern)
            Set Variable: sentInvoiceLineResult = payload
            Set Variable: logEntries append (object: "InvoiceLine__c (Sent)")
        Otherwise: (skip — Sent invoice failed, InvoiceLine not attempted)
```

Uses `sentInvoiceId`/`sentInvoiceResult` (not `invoiceId`/`invoiceResult`) to avoid any naming collision with `AddInvoices`, even though by the time this runs `AddInvoices` has already finished and those variables are no longer relevant for that row.

---

## 5. Account Status — nested inside `AddAccount`

New object: `Account_Status__c`. One record per account, not per invoice — `Effective_Date__c` is the **oldest** `deposit_date` across all of that account's `LaborAR.csv` rows (an account can have multiple AR rows, e.g. installment payments).

### Design choice: nested in `AddAccount`, not a separate post-`AddInvoices` sub-flow
Originally designed as a separate `AddAccountStatus` sub-flow that ran after `AddInvoices` completed. Revised to instead live directly inside `AddAccount`, gated on `vars.accountId != null`, because `vars.laborArRaw` is read before any inserts (including Account) — so the data's already available at Account-creation time, in the same per-row loop, no separate post-processing pass needed.

Initially this meant re-parsing `laborArRaw` from scratch inside the transform on every single account (O(rows × accounts)) — simple, but wasteful. Revised again: `vars.arRows` (filter/clean/sort) is now computed **once, upfront**, right after `LaborAR.csv` is read (see section 2's Flow Structure), before the main labor_std `For Each` even starts. Both `AddAccount` (filtered to one jobno) and `AddInvoices` (iterated whole) now just reuse that one pre-parsed `vars.arRows` — no re-parsing anywhere.

### Field Mapping (`transform-account-status.dwl`)
| Field | Source |
|---|---|
| Account__c | `vars.accountId` |
| Effective_Date__c | oldest `deposit_date` among `vars.arRows` matching `vars.row.jobno`, parsed to DataWeave `Date` type (same `Date`-not-`String` rule as Invoice__c/Payment__c date fields); `null` if no matching AR rows |
| Status__c | hardcoded `"Active"` for all |

### `transform-account-status.dwl`
```
%dw 2.0
output application/java

var matchingRows = vars.arRows filter (row) -> row.jobno == vars.row.jobno

var oldestDepositDate = if (sizeOf(matchingRows) > 0)
    (matchingRows orderBy (row) -> row.deposit_date as Date {format: "M/d/yyyy"})[0].deposit_date
  else null
---
{
    Account__c: vars.accountId,
    Effective_Date__c: if ((oldestDepositDate default "") != "") oldestDepositDate as Date {format: "M/d/yyyy"} else null,
    Status__c: "Active"
}
```

### Flow Structure (nested in `AddAccount`, see section 2's Flow Structure for full context)
```
Salesforce Create Account (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Account"]
Choice
    When #[vars.accountId != null]:
        Transform Message (transform-account-status.dwl)
        Salesforce Create Account_Status__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Account_Status__c"]
    Otherwise: (skip — Account failed, Account_Status__c not attempted)
```

---

## 6. Next Work Unit: Petroleum (In Progress)

Source data is very similar to Jewelry — but the `Petroleum` flow is being **built from scratch** in Studio, not copied from Jewelry's flow file. A raw filesystem copy of `Jewelry.xml` to `Petroleum.xml` was tried first and caused Studio to treat the two as linked (editing a property in one changed the same property in the other — root cause not diagnosed, likely Studio project/global-element caching) — see [[project_anypoint_salesforce_connectivity]]. Slower to build by hand, but avoids that bug. **Naming note**: the client uses "Mercantile" and "Petroleum" interchangeably — source files are prefixed `Merc` (`MercStd`, `MercAR`), but the work unit/Salesforce-facing naming stays "Petroleum" throughout this doc.

### Trigger File — `LoadReadyFlagPetroleum.csv`
Own sentinel file, separate from Jewelry's (see TODO in section 2 to rename Jewelry's to match: `LoadReadyFlagJewelry.csv`) — same reasoning and settings as Jewelry's trigger (section 2): Min Size `1`, created only after `MercStd.csv`/`MercAR.csv` (and the four truck files) are fully in place.

### Work Units
| File | Description |
|---|---|
| `MercStd.csv` | Petroleum equivalent of `LaborStd.csv` |
| `MercAR.csv` | Petroleum equivalent of `LaborAR.csv` |

**No `jobno` field anywhere in Petroleum** — unlike Jewelry, both `MercStd.csv` and `MercAR.csv` are keyed purely by `licenseno`. Confirmed field lists:
- `MercStd.csv`: `licenseno, processed, compname, respparty, add1, add2, city, state, zip, area_code, phone_no, contact_fname, contact_mi, contact_lname, contact_area_code, contact_telephone, email_addr, no_trucks, certificate, inspect_date, reinspect_date, no_insp_truck, no_non_truck, no_show, license_issued, insurance_agent, insurance_company, ins_expire_date, certif_dmv, certif_gu, date_issued, comments, batch_id` — no `jobno`, no `ID`
- `MercAR.csv`: `licenseno, pymt_amt, pymt_type, check_date, check_no, bank_no, check_amt, bad_check_flag, mo_ord_no, mo_ord_date, mo_ord_amt, cash_recpt_no, cash_pymt_date, cash_amt, tot_pymt_amt, deposit_voucher, deposit_date, budget_acc1, budget_acc2` — no `jobno`. Note the field is `tot_pymt_amt`, not `tot_pymt` (fixed in `transform-bla-petroleum.dwl`, which had assumed the Jewelry/`LaborAR.csv` name).

This ripples through several places that assumed a jobno, mirroring Jewelry too closely at first:
- `transform-filter-and-name-petroleum.dwl` / `transform-ar-filter-and-name-petroleum.dwl` — filter/clean `licenseno` only, no jobno handling, no "ID" rename (fixed, see commit history)
- `transform-location-petroleum.dwl` — `Description` reads "...Address for License No " ++ licenseno (was jobno)
- `transform-bla-petroleum.dwl` — `Description` reads "Legacy License Number: " ++ licenseno (was jobno); `ApplicationType` (New/Renewal) has no equivalent to Jewelry's jobno-last-2-digits trick — hardcoded `"TBD"` placeholder, logged as dev question #11
- **Still open**: Jewelry's `AddInvoices`/`blaJobnoLog` join Invoice__c/Payment__c back to the right BLA via `jobno`. Petroleum has no jobno to join on, so this needs a `blaLicenseLog` (or similar) keyed by `licenseno` instead — not yet designed, flag when building that part of the flow.

### Flow Structure (in progress — built incrementally in Studio, this reflects current state)
```
On New or Updated File (C:\data\, LoadReadyFlagPetroleum.csv)

File Read (Path: C:\data\MercStd.csv)
  → Transform Message (transform-filter-and-name-petroleum.dwl — filters rows with an invalid
    licenseno, strips Access's ".0" decimal suffix off licenseno; no jobno, no "ID" column,
    unlike LaborStd.csv)
  → Set Variable: mercStdRows = #[payload]

File Read (Path: C:\data\MercAR.csv)
  → Transform Message (transform-ar-filter-and-name-petroleum.dwl — same licenseno clean-up,
    sorts by deposit_date ascending)
  → Set Variable: arRows = #[payload] (same var name as Jewelry's vars.arRows — already referenced
    by transform-bla-petroleum.dwl's AmountPaid lookup)
```
Next: the vehicles file reads + `transform-vehicles-combine.dwl` join (see Vehicles Flow Structure above) feed into `vars.truckRows`, then `InitAssessmentQuestionVersion`/`InitAccountRecordType` sub-flows run once, then the main `For Each` over `vars.mercStdRows` starts — mirroring section 2's Flow Structure, minus `AddSentInvoice`.

**Do not carry over `AddSentInvoice`** (section 4) — that's a one-time Jewelry cutover requirement (old-system invoices with no AR payment record), not a general pattern. Strip it, its Flow Reference call, the `blaJobnoLog`-filter-to-Current step, and `transform-sent-invoice.dwl`/`transform-sent-invoiceline.dwl` out of the copied flow.

**Vehicles** — there's an additional source file listing vehicles, which adds data to a couple of the Assessment Question Responses. Unlike the Jewelry AQR transform (`transform-assessment-question-response.dwl`), which maps a fixed static list of 7 questions, Petroleum's AQR will need to handle **per-vehicle repetition** for whichever questions the vehicle data feeds — similar in shape to how Contacts handle "up to 4" respparty entries (`transform-contact.dwl`), not a fixed-count list.

#### Vehicles source file layout (wide/denormalized)
Four files, all sharing the same column shape — `TrucksReg01`/`TrucksReg02` (Current) and `TrucksHis01`/`TrucksHis02` (Historical), same relationship as `LaborStd`/`HisLaborStd`. The `01`/`02` split exists because the underlying source table was too wide to fit into Access for analysis as a single import, **not** because it's two logical tables — `01` and `02` together are one row per license.

Non-repeating columns (present once per row) — confirmed same on `TrucksReg01`/`TrucksHis01`:
| Column | Notes |
|---|---|
| `licenseno` | Join key back to `MercStd`/`MercAR` (same field used in `transform-bla-petroleum.dwl`'s AmountPaid lookup) |
| `inspect_comp_code` | |
| `inspect_comp` | |
| `tot_reg_trucks` | **`TrucksReg02`/`TrucksHis02` only** (not yet confirmed on `TrucksHis02` specifically, but unused downstream either way) |
| `batch_id` | **`TrucksReg02`/`TrucksHis02` only** (same caveat) |

Repeating columns — one set of 5 per truck slot, column names suffixed `N` (**no leading zero** — `truck_make1`, `truck_make2`, ... `truck_make39`/`truck_make40`... not `truck_make01`). **`TrucksReg01`/`02` (Current) and `TrucksHis01`/`02` (Historical) use different names for two of the five columns** — confirmed the hard way after `transform-vehicles-petroleum.dwl` first assumed one name for both:
| Meaning | TrucksReg column | TrucksHis column |
|---|---|---|
| Make | `truck_make` | `truck_make` |
| Year | `year` | `year` |
| Plate/reg number | `reg_truck_numb` | `reg_plate_numb` |
| Equipment number | `equipment_no` | `equipment_no` |
| Tested/sealed | `tested_sealed` | `date_tested` |

Slot numbering is continuous across the two files, not restarting: `N = 1-39` in `TrucksReg01`/`TrucksHis01`, `N = 40-56` in `TrucksReg02`/`TrucksHis02` — so up to **56 truck slots per license**, split 39/17 across the two files. A license with fewer than 56 actual trucks leaves the remaining slot columns blank — the transform needs to filter those out, not create 56 empty vehicle entries per license.

A truck slot `N` is considered populated (included in the output) if any of `truck_makeN`, `yearN`, or the plate column (`reg_truck_numbN`/`reg_plate_numbN` depending on source) is non-null — `equipment_no` and the tested/sealed column are **not used** anywhere in the Petroleum load and can be ignored.

**Source files**: `TrucksReg01.csv`, `TrucksReg02.csv`, `TrucksHis01.csv`, `TrucksHis02.csv` — headered CSVs (already-named columns, header: true), sitting in `C:\data\` alongside `MercStd.csv`/`MercAR.csv`. No positional renaming transform needed, unlike raw `laborstd.txt`/`his_lab.txt`.

**Join** — `01`/`02` combined by `licenseno` into one row per license, via `transform-vehicles-combine.dwl` (reused for both the Current pair and the Historical pair, same "one transform, two Set Variable calls" reuse pattern as `transform-laborstd-raw-name.dwl`), then Current + Historical concatenated into `vars.truckRows`:
```
File Read: C:\data\TrucksReg01.csv
  → Set Variable: truckPart1Rows = #[payload]
File Read: C:\data\TrucksReg02.csv
  → Set Variable: truckPart2Rows = #[payload]
Transform Message (transform-vehicles-combine.dwl — joins truckPart1Rows/truckPart2Rows on licenseno)
  → Set Variable: currentTruckRows = #[payload]

File Read: C:\data\TrucksHis01.csv
  → Set Variable: truckPart1Rows = #[payload]
File Read: C:\data\TrucksHis02.csv
  → Set Variable: truckPart2Rows = #[payload]
Transform Message (transform-vehicles-combine.dwl — same transform, reused)
  → Set Variable: historicalTruckRows = #[payload]

Set Variable: truckRows = #[vars.currentTruckRows ++ vars.historicalTruckRows]
```
Placed upfront, alongside the `LaborAR.csv` → `vars.arRows` read in the main Flow Structure (section 2) — parsed once before the main `For Each`, same "parse once, filter per-row inside the transform" pattern `vars.arRows` uses (no `SourceFileType` filtering needed here, same as `vars.arRows`'s `licenseno`-only matching in `transform-bla-petroleum.dwl`).

#### `PET_Delivery_Vehicles` JSON shape (confirmed)
The AQR field is a long text field — value is a JSON **string** (`write(..., "application/json")`), not a structured field. Confirmed shape is `{rows: [...], columns: [...]}`:

- `rows` — one object per populated truck slot: `{inService, vin, registrationExpiry, state, plateNumber, model, year, make}`. Mapping from source:
  - `make` ← `truck_makeN`, `year` ← `yearN`, `plateNumber` ← `reg_truck_numbN` (TrucksReg) or `reg_plate_numbN` (TrucksHis) — `transform-vehicles-petroleum.dwl` tries both since `vars.truckRows` mixes both sources
  - `vin`, `model` — hardcoded `""` (no source data)
  - `state` — hardcoded `"RI"`
  - `inService` — hardcoded `true` for every truck
  - `registrationExpiry` — **hardcoded placeholder** `"2026-04-09"`, real source unknown — logged as dev question #10
- `columns` — static metadata, identical on every record (field type/name/label for each of the 8 `rows` keys, for whatever UI renders this JSON) — see `transform-vehicles-petroleum.dwl` for the exact literal.

Implemented in `transform-vehicles-petroleum.dwl`, output `vars.deliveryVehiclesJson` (a Transform Message step ahead of the AQR transform), consumed by `transform-assessment-question-response-petroleum.dwl`'s `PET_Delivery_Vehicles` question as `ResponseText`.

#### Assessment Question Response (AQR) mapping
Like Jewelry, each Account gets a BLA, an Assessment, and a set of AQRs (`transform-assessment-question-response.dwl` pattern). **Difference from Jewelry**: Petroleum's AQRs get real values fed in, where Jewelry currently sends `null` for every response field regardless of question (see `transform-assessment-question-response.dwl` — all of `CurrencyValue`/`DateValue`/`IntegerResponseValue`/`ChoiceValue`/`ResponseText` are hardcoded `null`).

Petroleum's question list (order given, replaces Jewelry's 7-question fixed list — implemented in `transform-assessment-question-response-petroleum.dwl`):
| # | Question | Value |
|---|---|---|
| 1 | PET Name on Vehicle Different | hardcoded `false` (like Jewelry's nulls) |
| 2 | PET Name on Vehicle | `null` for all (like Jewelry) |
| 3 | PET Insurance Company | `MercStd.insurance_company` |
| 4 | PET Policy Expiration | `MercStd.ins_expire_date` |
| 5 | PET Date App Received | `MercStd.date_issued` |
| 6 | PET_Delivery_Vehicles | JSON string built by `transform-vehicles-petroleum.dwl` (see below) |

### Petroleum-specific transforms (new files, Jewelry's originals untouched)
Everything not listed here (`transform-address.dwl`, `transform-contact.dwl`, `transform-invoice.dwl`, `transform-payment.dwl`, etc.) is unchanged from Jewelry and reused as-is in the copied flow.

- **`transform-location-petroleum.dwl`** — same as `transform-location.dwl`, `Description` literal changed from `"Jewelry "` to `"Petroleum "`, and reads `"...Address for License No " ++ licenseno` instead of `"...Job No " ++ jobno` (MercStd has no jobno — see the no-jobno note above).
- **`transform-bla-petroleum.dwl`** — differs from `transform-bla.dwl` in several fields:
  - `Trade__c` — hardcoded to `"TBD"` placeholder (real value not yet decided — see dev question #9).
  - `ApplicationType` — hardcoded to `"TBD"` placeholder; no jobno to derive New/Renewal from — see dev question #11.
  - `Description` reads `"Legacy License Number: " ++ licenseno` instead of `"Legacy Job Number: " ++ jobno`.
  - `AmountPaid` — **not** hardcoded to `0` like Jewelry. Business rule: the `tot_pymt_amt` from the `MercAR` (AR) record with the **max** `deposit_date`, matched by `licenseno`. Implemented by filtering `vars.arRows` (Petroleum's pre-parsed AR rows, same "parse once upfront" pattern as Jewelry's `vars.arRows` — see section 2's Flow Structure and section 5) to `licenseno` matches, then taking the row with the latest `deposit_date` — mirror image of `transform-account-status.dwl`'s oldest-date logic (section 5), just `[-1]` (last, since `orderBy` is ascending) instead of `[0]`.
- **`transform-vehicles-combine.dwl`** — joins the `01`/`02` truck file pairs on `licenseno` into one row per license; reused once for the Current pair and once for the Historical pair (see Vehicles Flow Structure above).
- **`transform-vehicles-petroleum.dwl`** — builds the `PET_Delivery_Vehicles` JSON string (see shape above) from `vars.truckRows` filtered to the current `vars.row.licenseno`. Output of a dedicated Transform Message step, stored as `vars.deliveryVehiclesJson`, ahead of the AQR transform — same "compute once, stash in a var" shape as `vars.aqvMap`/`vars.arRows`.
- **`transform-assessment-question-response-petroleum.dwl`** — Petroleum's version of `transform-assessment-question-response.dwl`, 6-question list instead of Jewelry's 7, with real values instead of all-null (see AQR mapping above). Date fields assume `M/d/yyyy` format, same unconfirmed assumption as `transform-bla-petroleum.dwl`'s `deposit_date`.

### Open items
- `Trade__c` value for Petroleum — logged as dev question #9.
- `registrationExpiry` real source/value for `PET_Delivery_Vehicles` — logged as dev question #10.
- `ApplicationType` (New/Renewal) — no jobno to derive it from, logged as dev question #11.
- Whether `MercStd`/`MercAR`'s date columns (`deposit_date`, `ins_expire_date`, `date_issued`) match Jewelry's `LaborAR.csv` format (`M/d/yyyy`, non-padded — see section 3's Date Format note) needs confirming once real data is available; `transform-bla-petroleum.dwl` and `transform-assessment-question-response-petroleum.dwl` currently assume they do.
- **Needs verification in Studio**: confirm the CSV reader picks up headers correctly for all 4 truck files (`header: true`) and that `licenseno` comes through as the same type/format across `TrucksReg01`/`02`/`TrucksHis01`/`02` and `MercStd`/`MercAR` for the join/filter to match reliably.
- No jobno anywhere in Petroleum means Jewelry's `AddInvoices`/`blaJobnoLog` join needs a licenseno-keyed equivalent (`blaLicenseLog`?) — not yet designed, see no-jobno note above.

---

## 7. Next Work Unit: BiWeekly (Planned)

Same target objects as Jewelry: Account, Location/Address, Contact, BLA, Business License, Assessment/AQR, Invoice__c/InvoiceLine__c, Payment__c, Account_Status__c. Source data is **a single input file**, confirmed **one row per job** (not one row per invoice/deposit like `LaborAR.csv`).

**Key simplification vs. Jewelry**: Jewelry needs two files joined by jobno (`LaborStd.csv` for Account/Location/BLA, `LaborAR.csv` for Invoice__c/Payment__c) because a job can have multiple AR rows (e.g. several same-day deposits), so Invoice/Payment had to loop over the AR file separately from the account-level `For Each`, joined via `blaJobnoLog`. Since BiWeekly is one row per job, there's no join needed — Account/Location/BLA/Business License/Assessment/AQR/Invoice__c/InvoiceLine__c/Payment__c/Account_Status__c can all be created directly inside a single per-row `For Each`, no `blaJobnoLog`, no separate `AddInvoices` pass over a second file.

Same simplification applies to Account_Status__c: Jewelry's `transform-account-status.dwl` finds the **oldest** `deposit_date` across potentially several matching `vars.arRows` for a jobno (see section 5). With one row per job, `Effective_Date__c` is just that row's own `deposit_date` directly — no `vars.arRows` pre-parse, no `filter`/`orderBy`.

### Open questions
- Does BiWeekly need the Sent Invoice cutover logic (`AddSentInvoice`, section 4)? Default assumption is **no** — same reasoning as Petroleum (section 6): that's a one-time Jewelry-specific cutover, not carried forward unless told otherwise.
- Actual source file layout / column names not yet known — needed before building the transforms.

---

## PostgreSQL Reconciliation Log (deferred — see TODO above)

### DDL
```sql
CREATE TABLE import_log (
    id            SERIAL PRIMARY KEY,
    logged_at     TIMESTAMP DEFAULT NOW(),
    jobno         VARCHAR(20),
    object        VARCHAR(50),
    status        VARCHAR(10),
    salesforce_id VARCHAR(18),
    error_code    VARCHAR(100),
    error_message TEXT
);
```

---

## DataWeave Reference

### Gotcha: chained `filter`/`map` can get entangled — wrap `filter` in explicit parens
Chaining `X filter (row) -> BOOL_EXPR map (row) -> BODY` without wrapping the `filter` call in its own parentheses can, in some cases, cause DataWeave to evaluate the `filter` lambda's `matches`/boolean expression *as part of* the `map` callback's evaluation instead of treating `filter` as a fully-resolved prior step — surfacing as a confusing runtime error like `You called the function 'map' with these arguments: 1: Boolean (true) 2: Function (...)`. The error's stack trace is the tell: it shows `matches` called *from inside* `map`, not before it.

Observed trigger: this showed up once `map`'s body started with a parenthesized expression (`(row - "ID") ++ {...}`) instead of a plain object literal (`{...}`) — the object-literal form apparently gives the parser an unambiguous "new expression" signal that the parenthesized form doesn't.

Fix — always wrap the `filter` call in explicit parens when chaining into `map`:
```
(X filter (row) -> BOOL_EXPR)
  map (row) -> BODY
```
Applied in `transform1-filter-and-name.dwl` and `transform-ar-filter-and-name.dwl`.

### Log payload as JSON
```
#[output application/json --- payload]
```

### Log Salesforce Create response (exclude stackTrace)
```
#[output application/json --- 
    payload.items map (item) -> {
        (item - "exception"),
        (exception: {
            message: item.exception.message,
            successful: item.exception.successful,
            statusCode: item.exception.statusCode
        }) if (item.exception != null)
    }
]
```

### Access a field from current payload
```
#[payload.CompanyName]
```

### Reference a stored variable
```
#[vars.accountId]
```
