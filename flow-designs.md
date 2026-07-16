# Flow Designs

## 0. Source Data Pipeline (Client Files → Access → CSV Export)

Upstream of every Mule flow in this file: how the client's raw data becomes the CSVs the flows actually read. Two distinct legs, in and out of Access — don't conflate their formats:

**General shape, across all work units**: client files arrive as pipe-delimited `.unl` (no header row) → opened in Excel, reheadered, saved as `.csv` → imported into Access for analysis/prep → Access queries produce the CSVs the Mule flows actually consume, exported via an Access form button, with the `LoadReadyFlag*.csv` sentinel written last. **Each work unit has its own Access database** (Jewelry, Petroleum, BiWeekly are separate databases, not separate tables in one).

**`ExportCandidates` table + `IsExported` flag** — each work unit's Access database has an `ExportCandidates` table that joins against the other source tables, with an `IsExported` flag used to limit which records get included in a given export run. This is how test runs with a small number of accounts (e.g. the 2-account batch test that surfaced the `AddSentInvoice` bug) get scoped — not a separate test database, just fewer rows flagged for export in the same one.

**Access import settings** — when importing a prepared `.csv` into Access, check **"First Row Contains Field Names"** and set **Text Qualifier = `"`**. Easy to miss/default-wrong on Access's import wizard; get these wrong and either the header row imports as a data row, or quoted fields (e.g. an address containing a comma) split incorrectly.

**Plate/reg number columns must be imported as Text, not Number** — e.g. `reg_plate_no1` (and by extension the rest of the `reg_truck_numbN`/`reg_plate_numbN` slot columns, see Petroleum vehicles section) needs its Access field type set to Text. Left as Number, Access/Excel auto-typing silently strips leading zeros and mangles any non-numeric plate values — a classic Access import gotcha, not specific to this one column.

**More Text-not-Number import fields (Petroleum)**: `bank_no` in `MercARHis`, `check_no` in `MercAR` — same leading-zero/mangling risk as the plate columns above. (`MercARHis` confirms the historical counterpart of `MercAR` is a distinct table, combined via `SourceFileType` — same pattern as `MercStd`/its historical counterpart, see SourceFileType note in section 6.)

### Incoming leg — client files → Access
The client's **initial** data delivery (covering all work units — Jewelry, Petroleum, BiWeekly) was one `.xlsx` file per source table, each with a header row. **Going forward**, incoming files arrive as **`.unl`, pipe-delimited, no header row** instead — same column shape as the originals otherwise. This only affects how these files get imported into Access; it does not touch the Mule-facing CSVs (see outgoing leg below).

Since the `.unl` files have no header row, importing them requires a reheadering step:
1. ~~Open the `.unl` file in Excel (pipe-delimited).~~
2. ~~Add the column names back, matching the original (headered) source file for that table.~~
3. ~~Add a `SourceFileType` column, hardcoded per source file (not derived from any column in the data) — e.g. `"Current"` for `LaborStd`, `"Historical"` for `LaborStdHis`.~~
4. ~~Save as `.xlsx`.~~

Steps 1-4 (manual Excel reheadering) are superseded for LaborStd by the **`ImportSourceData`** Mule flow — see subsection below. It reads the raw pipe-delimited files directly, assigns column names positionally, adds `SourceFileType`, and writes the combined result as `.csv` (not `.xlsx` — CSV avoids the memory overhead of building an xlsx workbook in memory, see note below). This is what section 2 refers to as the `SourceFileType` column distinguishing merged Current/Historical records once these land in the combined `LaborStd`/`LaborAR` Access tables.

**For every other source table** (Petroleum's `MercStd`/`MercAR`, `TrucksReg`/`TrucksHis`, etc. — anything `ImportSourceData` doesn't cover), steps 1-4 still apply manually: reheader in Excel, and **remember to add the `SourceFileType` column by hand** (hardcoded `"Current"`/`"Historical"` per source file) before importing into Access — it's not derived from any column in the data, so it's easy to forget since `ImportSourceData` does this automatically for LaborStd.

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
| `InitAccountRecordType` | **Planned, not actually built in Jewelry** — see note below the sub-flow body |
| `AddAccount` | Salesforce Create Account, Result & Log Pattern; sets `accountId`. If `accountId != null`, also Choice-gated creates one Account_Status__c (filters the pre-parsed `vars.arRows` to this row's jobno, takes the oldest `deposit_date` — see section 5) |
| `AddLocationsAndAddresses` | Location(s) → per-location Choice-gated Address__c → PartyAddress__c (see Flow Structure below) |
| `AddContacts` | Contact list create (0-4), List Result & Log Pattern; independent, no gating |
| `AddBusinessLicenseApp` | BLA → Choice-gated Business License / Assessment / Assessment Question Response chain; sets `blaId`, appends to `blaJobnoLog` |
| `AddSentInvoice` | Called **after `AddInvoices` completes**, once per Current-sourced BLA (`blaJobnoLog` filtered on `sourceFileType == "Current"`) — must run last so the Salesforce trigger marks this as the "Active" invoice on the BLA. Creates one Invoice__c (`InvoiceStatus__c: "Sent"`) + InvoiceLine__c per cutover account, no Payment__c (see section 4) |
| `AddInvoices` | Invoice Load — called once, processing `LaborAR.csv` rows via `vars.blaJobnoLog` lookup → Invoice__c → Choice-gated InvoiceLine__c/Payment__c (see section 3) |

`InitAssessmentQuestionVersion` and `InitAccountRecordType` both run once at the start of the flow (before the labor_std `For Each`); the other sub-flows are called per-row (or, for `AddInvoices`, per-file) from within the relevant loop.

### InitAssessmentQuestionVersion (sub-flow body)
```
Salesforce Query: SELECT Id, QuestionText, Name, VersionNumber FROM AssessmentQuestionVersion
                   WHERE Name IN (<Jewelry's 7 question names>) AND Status = 'Active'
                   ORDER BY Name ASC, VersionNumber ASC
Transform Message (transform-aqv-lookup.dwl — reduce over payload keyed by Name; since results
  are ordered by VersionNumber ASC within each Name, each reduce step overwrites the previous
  entry for that Name, so the map ends up holding the highest/latest VersionNumber per question
  — a cheap way to get "latest active version per question" without a subquery)
Set Variable: aqvMap = #[payload]
```

### InitAccountRecordType (sub-flow body — planned, never actually implemented in Jewelry)
**Correction**: this was designed as the fix for a hardcoded `RecordTypeId` breaking after a sandbox refresh, but Jewelry's `AddAccount`/`transform2-account.dwl` still hardcodes the `RecordTypeId` directly today — this sub-flow was never built there. **TODO**: retrofit Jewelry to use this same query-based approach, so it stops breaking on sandbox refresh.
```
Salesforce Query: SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account'
Set Variable: accountRecordTypeId = #[payload[0].Id]
```
`DeveloperName` is a fixed constant known at design time (not row data), so it's embedded directly in the query text rather than bound as a parameter — the "never manually quote a bind parameter" rule (see Key Notes in section 1) only applies to values built from row/user data, not literals like this.

**Why this matters**: a hardcoded `RecordTypeId` breaks after a sandbox refresh (refreshes regenerate Salesforce record Ids — see [[project_anypoint_salesforce_connectivity]]). `DeveloperName` stays stable across refreshes, so querying by it once at flow start avoids that breakage. **Petroleum builds this sub-flow for real** (see section 6) since it's being built from scratch anyway — same `Business_Account` DeveloperName as Jewelry's hardcoded value.

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
- **Build a `CleanupJewelry` sub-flow** (2026-07-14) — Petroleum and BiWeeklyPayroll both now have their own dedicated cleanup sub-flow (`CleanupPetroleum`/`CleanupBiWeeklyPayroll`: `import_log.csv` write, BLA-log audit write, processed-file archiving, called at the very end of the main flow). Jewelry still does this inline/not-at-all — retrofit it to match once the other two are confirmed working, so all three work units follow the same convention.
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

**`MercStd`/`MercAR` date columns hit the same `0:00:00` Access export issue as Jewelry's `LaborAR.csv`** (see section 3's Date Format note) — `deposit_date` (`MercAR`) came through as e.g. `8/23/2016 0:00:00`, failing the `Date {format: "M/d/yyyy"}` coercion with the same "cannot coerce String to Date" error seen on Jewelry. Root cause and fix are identical: the Access column was typed as Date/Time; retype it to **Short Text** before CSV export to drop the time component while keeping the non-padded `M/d/yyyy` string. Confirmed on `MercAR.deposit_date`, `MercStd.date_issued`, and (while testing AQR — it threw the same coercion error via `transform-assessment-question-response-petroleum.dwl`'s `PET Policy Expiration` question) `MercStd.ins_expire_date`, all fixed by retyping to Short Text. `MercAR`'s `check_date`/`mo_ord_date`/`cash_pymt_date` still haven't been individually confirmed — check each before assuming it's clean.

**`SourceFileType` still applies** — these field lists are the native MercStd/MercAR table columns; `SourceFileType` (`Current`/`Historical`) is a column manually appended during export, same pattern as Jewelry's `LaborAR.csv` (not the automated `ImportSourceData` flow, which only covers `LaborStd.csv`) — so `vars.row.SourceFileType` is available on every row read from the final `MercStd.csv`/`MercAR.csv`, same as Jewelry, even though it wasn't in the "native fields" list above.

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
  → Set Variable: mercArRows = #[payload] (deliberately distinct from Jewelry's vars.arRows —
    referenced by transform-bla-petroleum.dwl's AmountPaid lookup and
    transform-account-status-petroleum.dwl)
```
The vehicles file reads + `transform-vehicles-combine.dwl` join (see Vehicles Flow Structure above) feed into `vars.truckRows`, then `InitAssessmentQuestionVersionPetroleum`/`InitAccountRecordTypePetroleum` sub-flows run once (see above), then the main `For Each` over `vars.mercStdRows` starts.

**Account/Contact field mismatches vs. Jewelry** — `MercStd.csv` has a very different shape than `LaborStd.csv` for these two objects, caught after assuming Jewelry's `transform2-account.dwl`/`transform-contact.dwl` fields would carry over:
- **Account** (`transform-account-petroleum.dwl`, new file) — Jewelry's account fields (`fein`, `name`, `company`, `bustype`, `sic`) don't exist on `MercStd`. Petroleum only populates: `RecordTypeId` (`vars.accountRecordTypeId`), `Name` ← `compname`, `DBA_Name__c` ← `respparty`, `BillingStreet`/`BillingCity`/`BillingState`/`BillingPostalCode` (same `add1`+`add2`/`city`/`state`/`zip` logic as Jewelry, `stateNames` lookup duplicated in the new file). No `Federal_Tax_ID__c`, `Business_Entity_Type__c`, or `SicDesc` — left unset entirely, not even null.
- **Contact** (`transform-contact-petroleum.dwl`, new file) — Jewelry's `respparty1`-`respparty4` free-text-with-title pattern doesn't apply; `MercStd` has exactly one already-structured contact: `contact_fname`/`contact_mi`/`contact_lname` (no parsing needed), `contact_area_code`+`contact_telephone` → `Phone` (format assumption: `"area-telephone"`, not yet confirmed), `email_addr` → `Email` (Jewelry's Contact creation never sets one), `Title` hardcoded `"Petroleum"` (not derived, unlike Jewelry's title-parsing). **Only created if `contact_fname` or `contact_lname` is non-blank** — unlike Jewelry's up-to-4 loop, this is a single optional Contact, so the transform returns `[]` (not a list with a mostly-empty record) when both are blank.

**Issue-date equivalent** — Jewelry's `transform-business-license.dwl`/`transform-assessment.dwl`/`transform-partyaddress.dwl` all derive their date fields from `vars.row.issue_date`, which doesn't exist on `MercStd` either. Confirmed: use `date_issued` for all three (same field already used for the "PET Date App Received" AQR question) — new files `transform-business-license-petroleum.dwl`, `transform-assessment-petroleum.dwl`, `transform-partyaddress-petroleum.dwl`, otherwise identical to Jewelry's, `M/d/yyyy` format per the existing MercStd date-format assumption (not Jewelry's `MM/dd/yyyy`).

**Account_Status__c** (`transform-account-status-petroleum.dwl`, new file) — same oldest-`deposit_date`-among-matching logic as Jewelry's `transform-account-status.dwl`, just matched by `licenseno` instead of `jobno`, and reading `vars.mercArRows` instead of `vars.arRows`.

**Reused as-is, no Petroleum variant needed**: `transform-address.dwl` (Address__c — no jobno/issue_date reference, `add1`/`add2`/`city`/`state`/`zip` all present on `MercStd`), `transform-location-results.dwl` (pure Create-response mapping, no row fields).

**`vars.licenseTypeId`** — referenced by both `transform-bla-petroleum.dwl` and `transform-business-license-petroleum.dwl`. **Stopgap wired into Studio** (both Jewelry and Petroleum): a Salesforce Query + Set Variable added right before the BLA transform to populate it. Dev question #1 stays open regardless — this unblocks testing, but isn't confirmed as the right long-term source/logic.

**`blaLicenseLog`, not `blaJobnoLog`** — Petroleum's equivalent of Jewelry's `blaJobnoLog` is keyed by `licenseno` instead of `jobno`; used later by a licenseno-keyed `AddInvoices` equivalent (not yet built, see earlier note).

**Log entries use `licenseno` under the existing `jobno` column** — rather than changing the `import_log` table/CSV schema, Petroleum's `logEntries` appends keep the same shape as Jewelry's (`jobno, object, status, salesforce_id, error_code, error_message`) and just put `vars.row.licenseno` in the `jobno` slot — a deliberate reuse of the generic "row business key" column, not a mistake.

### Flow Structure — main `For Each` (Petroleum)
```
For Each row: (Collection: #[vars.mercStdRows])
    → Set Variable: row = #[payload]

    → Flow Reference: AddAccountPetroleum
        → Transform Message (transform-account-petroleum.dwl)
        → Salesforce Create Account (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
          object: "Account"; sets accountId] (jobno slot in logEntries = vars.row.licenseno)
        → Choice
            When #[vars.accountId != null]:
                → Transform Message (transform-account-status-petroleum.dwl)
                → Salesforce Create Account_Status__c (Records: #[[payload]]) → [Result & Log
                  Pattern → logEntries, object: "Account_Status__c"]
            Otherwise: (skip)

    → Flow Reference: AddLocationsAndAddressesPetroleum
        → Transform Message (transform-location-petroleum.dwl — 1 or 2 items)
        → Set Variable: locationList = payload
        → Salesforce Create Location(s): Records = vars.locationList
        → Transform Message (transform-location-results.dwl — reused, unchanged)
        → Set Variable: locationResults = payload
        → For Each (Collection: #[vars.locationResults]):
            → Set Variable (locationId = #[payload.locationId])
            → Set Variable (addressType = #[payload.addressType])
            → Set Variable: logEntries = (vars.logEntries default []) ++ [{ jobno: vars.row.licenseno,
              object: "Location", status: if (payload.success) "Success" else "Failed",
              salesforce_id: vars.locationId, error_code: payload.errorCode, error_message: payload.errorMessage }]
            → Choice
                When #[vars.locationId != null]:
                    → Transform Message (transform-address.dwl — reused, unchanged) → Salesforce
                      Create Address__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                      object: "Address__c"; sets addressId]
                    → Choice
                        When #[vars.addressId != null]:
                            → Transform Message (transform-partyaddress-petroleum.dwl) → Salesforce
                              Create PartyAddress__c (Records: #[[payload]]) → [Result & Log Pattern
                              → logEntries, object: "PartyAddress__c"]
                        Otherwise: (skip — Address failed)
                Otherwise: (skip — Location failed, Address/PartyAddress not attempted)

    → Flow Reference: AddContactsPetroleum
        → Transform Message (transform-contact-petroleum.dwl — 0 or 1 Contact, see field mismatch
          note above)
        → Salesforce Create Contact (Records: #[payload]) → [List Result & Log Pattern → logEntries,
          object: "Contact"] (independent — no gating)

    → Flow Reference: AddBusinessLicenseAppPetroleum
        → Transform Message (transform-bla-petroleum.dwl)
        → Salesforce Create Business License Application (AccountId = accountId, Records: #[[payload]])
          → [Result & Log Pattern → logEntries, object: "BusinessLicenseApplication"; sets blaId]
        → Choice
            When #[vars.blaId != null]:
                → Set Variable: blaLicenseLog = (vars.blaLicenseLog default []) ++ [{ licenseno:
                  vars.row.licenseno, blaId: vars.blaId, accountId: vars.accountId, sourceFileType:
                  vars.row.SourceFileType }]
                → Transform Message (transform-business-license-petroleum.dwl) → Salesforce Create
                  Business License (linked to blaId, Records: #[[payload]]) → [Result & Log Pattern
                  → logEntries, object: "BusinessLicense"]
                → Transform Message (transform-assessment-petroleum.dwl) → Salesforce Create Assessment
                  (linked to blaId, Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                  object: "Assessment"; sets assessmentId]
                → Transform Message (transform-vehicles-petroleum.dwl) → Set Variable:
                  deliveryVehiclesJson = #[payload] (must run before the AQR transform below, which
                  reads vars.deliveryVehiclesJson)
                → Transform Message (transform-assessment-question-response-petroleum.dwl — uses
                  vars.assessmentId, vars.aqvMap, vars.deliveryVehiclesJson; builds list of 6)
                → Salesforce Create Assessment Question Response (Records: #[payload]) → [List Result
                  & Log Pattern → logEntries, object: "AssessmentQuestionResponse"]
                → Transform Message (transform-contentnote-petroleum.dwl) → Salesforce Create
                  ContentNote (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                  object: "ContentNote"; sets contentNoteId]
                → Choice
                    When #[vars.contentNoteId != null]:
                        → Transform Message (transform-contentdocumentlink-petroleum.dwl) →
                          Salesforce Create ContentDocumentLink (Records: #[[payload]]) → [Result
                          & Log Pattern → logEntries, object: "ContentDocumentLink"]
                    Otherwise: (skip — ContentNote failed)
            Otherwise: (skip — BLA failed, BL/Assessment/AQR/ContentNote not attempted)
```
**Update (2026-07-14)**: `import_log.csv`/processed-file-archiving now built as a separate **`CleanupPetroleum`** sub-flow, called at the very end of the main flow (after the `For Each`, `AddInvoicesPetroleum`, **and now `AddSentInvoicePetroleum`** — see below — all complete) — kept as its own named sub-flow rather than inline steps at the tail of the main flow body, for the same "one responsibility per sub-flow" reasoning as `AddAccount`/`AddContacts`/etc. Contains: File Write `import_log.csv` (`vars.logEntries as CSV`), then File Move `MercStd.csv`/`MercAR.csv`/all 4 truck files → `C:\data\processed\`, done last so a mid-flow error leaves source files in place for retry. **TODO**: Jewelry doesn't have this yet either — retrofit Jewelry with its own `CleanupJewelry` sub-flow (same pattern, `LaborStd.csv`/`LaborAR.csv`) at some point.

Right after the main `For Each` completes (same position as Jewelry's `bla_jobno_map.csv` write relative to its `AddInvoices` call), before `Flow Reference: AddInvoicesPetroleum`:
```
File Write: C:\data\bla_license_map.csv (overwrite, content = #[vars.blaLicenseLog as CSV] —
  debug/audit artifact, same as Jewelry's bla_jobno_map.csv; AddInvoicesPetroleum uses
  vars.blaLicenseLog directly in memory, no read-back needed)
```

### AddInvoicesPetroleum sub-flow
Licenseno-keyed equivalent of Jewelry's `AddInvoices` (section 3) — same grain (1 row = 1 Invoice__c = 1 InvoiceLine__c = 1 Payment__c), same `pymt_type` discriminator (`K`/`C`/`M` → Check/Cash/Money Order), called once via Flow Reference after the main `For Each` (and the `bla_license_map.csv` write above) complete, reading `vars.mercArRows` (already parsed/sorted oldest-first by `transform-ar-filter-and-name-petroleum.dwl`).

**Field differences from `LaborAR.csv`** — `MercAR.csv` has `pymt_amt` where `LaborAR.csv` has `pymt_code_amt`, and has no `pymt_code`/`refund_code`/`refund_code_amt`/`misc_code`/`misc_code_amt`/`misc_desc`/`appnumb`/`batchid`/`remarks` at all (see the confirmed `MercAR.csv` field list earlier in this section). Otherwise the fields `AddInvoices` needs (`pymt_type`, `check_date`/`check_no`, `cash_pymt_date`/`cash_recpt_no`, `mo_ord_date`/`mo_ord_no`, `deposit_date`) all exist on `MercAR.csv` unchanged.

- **`transform-invoice-petroleum.dwl`** (new file) — **Correction**: initially reused `transform-invoice.dwl` as-is since no source fields differ, but Petroleum has its own business rule for `InvoiceDate__c`: use the `pymt_type`-driven date (`check_date`/`cash_pymt_date`/`mo_ord_date`) same as Jewelry, but if that date is blank, **fall back to `deposit_date`** instead of leaving it `null`. Jewelry's `transform-invoice.dwl` has no such fallback. `DueDate__c`/`InvoiceStatus__c` logic otherwise unchanged.
- **`transform-invoiceline-petroleum.dwl`** (new file) — same as `transform-invoiceline.dwl` except `UnitPrice__c` reads `vars.row.tot_pymt_amt` instead of `vars.row.pymt_code_amt` — **not** `pymt_amt` (same correction as `Payment__c.Amount__c` above — both use the total payment amount), and defaults to `0` (not `null`) when blank — deliberate Petroleum-specific choice, unlike Jewelry's `null`-on-blank.
- **`transform-payment-petroleum.dwl`** (new file) — same as `transform-payment.dwl` except `Amount__c` reads `vars.row.tot_pymt_amt` instead of `vars.row.pymt_code_amt` — **not** `pymt_amt` (confirmed correction: `Payment__c.Amount__c` is the total payment amount, same field `transform-bla-petroleum.dwl`'s `AmountPaid` lookup already uses) — and, same as `UnitPrice__c` above, defaults to `0` (not `null`) when blank; `PaymentDate__c`/`ReceiptDate__c`/`Payment_Method__c`/`ReferenceNumber__c` logic unchanged. Also populates `Notes__c: "Bank_NO" ++ bankNo` (Petroleum-only field, no Jewelry equivalent) — `bank_no` is a numeric Access column, so it gets the same defensive `splitBy "."` decimal-strip treatment as `check_no`/`cash_recpt_no`/`mo_ord_no`. **Hit and resolved**: adding `Notes__c` initially threw `SALESFORCE:INVALID_INPUT` with an unhelpful masked error (`Unable to find a deserializer for the type common.api.soap.wsdl.QueryResult` — a Mule Salesforce connector quirk that hides the real fault behind a generic deserialization crash). Root cause was the same class of issue as `dev-questions.md` #3 (`Legacy_License_Number__c`): the integration user's profile lacked Edit field-level security on `Payment__c.Notes__c`. Fixed by granting FLS access, same as before — worth checking FLS first (before assuming a field-type/value problem) any time a brand-new custom field throws this specific masked deserializer error on Create.
- **`transform-ar-lookup-petroleum.dwl`** (new file) — `(vars.blaLicenseLog filter (r) -> r.licenseno == vars.row.licenseno)[0] default {}`, licenseno equivalent of `transform-ar-lookup.dwl`'s jobno filter.

Flow Structure (mirrors section 3's `AddInvoices`, licenseno instead of jobno throughout):
```
For Each (Collection: #[vars.mercArRows]):
      → Set Variable: row = #[payload]
      → Transform Message (transform-ar-lookup-petroleum.dwl — finds {licenseno, blaId, accountId}
        from vars.blaLicenseLog by licenseno; {} if no match)
      → Set Variable: blaAccountLookup = payload
      → Set Variable: blaId = vars.blaAccountLookup.blaId
      → Set Variable: accountId = vars.blaAccountLookup.accountId
      → Choice
          When #[vars.blaId != null and vars.accountId != null]:
              → Transform Message (transform-invoice-petroleum.dwl — InvoiceDate__c falls back to
                deposit_date if the pymt_type-driven date is blank, see below) → Salesforce Create
                Invoice__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                object: "Invoice__c", jobno slot = vars.row.licenseno; sets invoiceId]
              → Choice
                  When #[vars.invoiceId != null]:
                      → Transform Message (transform-invoiceline-petroleum.dwl) → Salesforce Create
                        InvoiceLine__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                        object: "InvoiceLine__c"]
                      → Transform Message (transform-payment-petroleum.dwl) → Salesforce Create
                        Payment__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
                        object: "Payment__c"]
                  Otherwise: (skip — Invoice failed, InvoiceLine/Payment not attempted)
          Otherwise: (skip — no matching BLA/Account for this licenseno; log explicitly, same
            NO_BLA_MATCH pattern as section 3, jobno slot = vars.row.licenseno)
```

**Reversed (2026-07-16): Petroleum does carry over a Sent Invoice cutover flow after all.** Originally decided this was Jewelry-only and stripped out of the copied flow.

### AddSentInvoicePetroleum sub-flow

Licenseno-keyed equivalent of section 4's `AddSentInvoice`, called after `AddInvoicesPetroleum` completes (same ordering constraint as Jewelry — this must be the last invoice created per BLA so the Salesforce trigger marks it "Active"). Field mapping and structure are otherwise identical to Jewelry's — same hardcoded `DueDate__c: 9/30/2026`, `InvoiceDate__c: 8/1/2026`, `InvoiceStatus__c: "Sent"`, no `Payment__c`, same `UnitPrice__c: 120`/`Quantity__c: 1`/`LineType__c: "Base Fee"`/`ProrateFactor__c: 100` InvoiceLine__c — **one rule difference**:

**Skip the Sent invoice entirely if `MercAR` already shows a 2026 `deposit_date` for that `licenseno`** — same "already paid this year" check `transform-bla-petroleum.dwl`'s Status rule uses (a real AR payment already came in, so the cutover placeholder invoice isn't needed). Unlike Jewelry, where every Current-sourced account unconditionally gets a Sent invoice.

New files:
- **`transform-sent-invoice-filter-petroleum.dwl`** — replaces the plain `sourceFileType == "Current"` filter Jewelry uses inline. Filters `vars.blaLicenseLog` to entries where `sourceFileType == "Current"` **and** no matching `vars.mercArRows` row for that `licenseno` has a `deposit_date` whose year is `2026` (same hardcoded-2026, filter/`sizeOf`-based check as `transform-bla-petroleum.dwl`, wrapped in a local `fun hasCurrentYearDeposit(licenseno)` here since it's applied per log entry rather than once).
  - **Debugging (2026-07-16), resolved**: no Sent invoices were coming out at all. Traced via a Logger dumping `vars.blaLicenseLog` right before this Transform Message step — it came back `null`. Root cause: a Studio-side variable naming typo, unrelated to this file's DataWeave — the Set Variable step(s) referenced `blaLicensenoLog`, not `blaLicenseLog` (the name this transform, `AddInvoicesPetroleum`, and `transform-ar-lookup-petroleum.dwl` all actually use). Not a precedence bug after all; the defensive parens added around `not` (`(entry.sourceFileType == "Current") and (not hasCurrentYearDeposit(entry.licenseno))`) were unnecessary but left in place since they're harmless and match this project's established caution around keyword-operator precedence (see the `contains`/`or` gotcha in the DataWeave Reference section).
- **`transform-sent-invoice-petroleum.dwl`** — identical field mapping to `transform-sent-invoice.dwl` (reads `vars.row.accountId`/`vars.row.blaId` from the filtered `blaLicenseLog` entry, same as Jewelry reads from `blaJobnoLog`).
- **`transform-sent-invoiceline-petroleum.dwl`** — identical to `transform-sent-invoiceline.dwl`.

### Flow Structure (`AddSentInvoicePetroleum` sub-flow body)
Same shape as Jewelry's `AddSentInvoice` (section 4), just the new filter transform in place of the inline `sourceFileType` filter:
```
Transform Message (transform-sent-invoice-filter-petroleum.dwl — filters vars.blaLicenseLog to
  Current-sourced entries with no 2026 deposit_date in vars.mercArRows)
Set Variable: currentLicenses = payload
For Each (Collection: #[vars.currentLicenses]):
    Set Variable: row = #[payload] (row = {licenseno, blaId, accountId, sourceFileType})
    Transform Message (transform-sent-invoice-petroleum.dwl)
    Salesforce Create Invoice__c (Records: #[[payload]])
    Transform Message: extract result (single-item Result & Log Pattern)
    Set Variable: sentInvoiceResult = payload
    Set Variable: sentInvoiceId = vars.sentInvoiceResult.id
    Set Variable: logEntries append (object: "Invoice__c (Sent)", jobno slot = vars.row.licenseno)
    Choice
        When #[vars.sentInvoiceId != null]:
            Transform Message (transform-sent-invoiceline-petroleum.dwl)
            Salesforce Create InvoiceLine__c (Records: #[[payload]])
            Transform Message: extract result (single-item pattern)
            Set Variable: sentInvoiceLineResult = payload
            Set Variable: logEntries append (object: "InvoiceLine__c (Sent)")
        Otherwise: (skip — Sent invoice failed, InvoiceLine not attempted)
```
Called via Flow Reference right after `AddInvoicesPetroleum` (no input needed — `vars.blaLicenseLog`/`vars.mercArRows` persist as flow variables), and **before** `CleanupPetroleum` — update `CleanupPetroleum`'s trigger condition (see below) to wait for this too, not just `AddInvoicesPetroleum`.

**Vehicles** — there's an additional source file listing vehicles, which adds data to a couple of the Assessment Question Responses. Unlike the Jewelry AQR transform (`transform-assessment-question-response.dwl`), which maps a fixed static list of 7 questions, Petroleum's AQR will need to handle **per-vehicle repetition** for whichever questions the vehicle data feeds — similar in shape to how Contacts handle "up to 4" respparty entries (`transform-contact.dwl`), not a fixed-count list.

#### Vehicles source file layout (wide/denormalized)
Four files, all sharing the same column shape — `TrucksReg01`/`TrucksReg02` (Current) and `TrucksHis01`/`TrucksHis02` (Historical), same relationship as `LaborStd`/`HisLaborStd`. The `01`/`02` split exists because the underlying source table was too wide to fit into Access for analysis as a single import, **not** because it's two logical tables — `01` and `02` together are one row per license. **Confirmed**: the split happens in **Excel** (part of the general `.unl` → Excel → Access leg — see section 0), not in Access — `01` gets the columns up through truck slot 39, `02` gets the remaining truck slots plus the trailing non-truck columns (`tot_reg_trucks`, `batch_id`).

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

A truck slot `N` is considered populated (included in the output) if any of `truck_makeN`, `yearN`, or the plate column (`reg_truck_numbN`/`reg_plate_numbN` depending on source) is non-blank — `equipment_no` and the tested/sealed column are **not used** anywhere in the Petroleum load and can be ignored. **Correction**: blank slot cells come through from the CSV reader as empty string `""`, not `null` (the column header exists across all 56 slots even when a license has fewer trucks) — `transform-vehicles-petroleum.dwl`'s populated check must test `(value default "") != ""`, not `value != null`; the latter let all 56 slots through as "populated" in testing.

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

**InitAssessmentQuestionVersion (Petroleum)** — own sub-flow, not shared with Jewelry's, since it needs a different `Name IN (...)` list (Petroleum's 6 questions vs Jewelry's 7). Same query shape and same `transform-aqv-lookup.dwl` reused (see section 2's version of this sub-flow for why the `ORDER BY ... VersionNumber ASC` + reduce-overwrite pattern gets the latest active version per question):
```
Salesforce Query: SELECT Id, QuestionText, Name, VersionNumber FROM AssessmentQuestionVersion
                   WHERE Name IN ('PET Name on Vehicle Different', 'PET Name on Vehicle',
                   'PET Insurance Company', 'PET Policy Expiration', 'PET Date App Received',
                   'PET_Delivery_Vehicles') AND Status = 'Active'
                   ORDER BY Name ASC, VersionNumber ASC
Transform Message (transform-aqv-lookup.dwl — same transform, reused)
Set Variable: aqvMap = #[payload]
```
**Needs verification in Studio**: confirm these 6 `AssessmentQuestionVersion.Name` values (especially `PET_Delivery_Vehicles`'s underscores) exist and are `Status = 'Active'` before relying on this query.

**InitAccountRecordType (Petroleum)** — built fresh, since Jewelry never actually built this sub-flow (it hardcodes `RecordTypeId` instead — see the correction in section 2). Same `Business_Account` `DeveloperName`, same query as documented in section 2's sub-flow body:
```
Salesforce Query: SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account'
Set Variable: accountRecordTypeId = #[payload[0].Id]
```
Placed upfront, alongside the `MercAR.csv` → `vars.mercArRows` read in the main Flow Structure above — parsed once before the main `For Each`, same "parse once, filter per-row inside the transform" pattern Jewelry's `vars.arRows` uses (no `SourceFileType` filtering needed here, same as `vars.mercArRows`'s `licenseno`-only matching in `transform-bla-petroleum.dwl`).

#### `PET_Delivery_Vehicles` JSON shape (confirmed)
The AQR field is a long text field — value is a JSON **string** (`write(..., "application/json")`), not a structured field. Confirmed shape is `{rows: [...], columns: [...]}`:

- `rows` — one object per populated truck slot: `{inService, vin, registrationExpiry, state, plateNumber, model, year, make}`. Mapping from source:
  - `make` ← `truck_makeN`, `year` ← `yearN`, `plateNumber` ← `reg_truck_numbN` (TrucksReg) or `reg_plate_numbN` (TrucksHis) — `transform-vehicles-petroleum.dwl` tries both since `vars.truckRows` mixes both sources
  - `vin`, `model` — hardcoded `""` (no source data)
  - `state` — hardcoded `"RI"`
  - `inService` — hardcoded `true` for every truck
  - `registrationExpiry` — **hardcoded placeholder** `"2026-04-09"`, real source unknown — logged as dev question #10
- `columns` — static metadata, identical on every record (field type/name/label for each of the 8 `rows` keys, for whatever UI renders this JSON) — see `transform-vehicles-petroleum.dwl` for the exact literal.

Implemented in `transform-vehicles-petroleum.dwl`, output `vars.deliveryVehiclesJson` (a Transform Message step ahead of the AQR transform), consumed by `transform-assessment-question-response-petroleum.dwl`'s `PET_Delivery_Vehicles` question as `ResponseText`. **Correction**: the transform initially used `output application/json` and returned the `{rows, columns}` object directly, which left `vars.deliveryVehiclesJson` holding a structured Java Map, not a literal string — this passed a non-String into `ResponseText` and threw the same Salesforce-connector `ArrayStoreException` (`arraycopy: element type mismatch ... java.lang.String`) as the `ChoiceValue` Boolean issue above. Fixed by switching to `output application/java` and explicitly serializing with `write({rows: trucks, columns: columns}, "application/json")`, so the variable holds an actual String as the design always specified.

#### Assessment Question Response (AQR) mapping
Like Jewelry, each Account gets a BLA, an Assessment, and a set of AQRs (`transform-assessment-question-response.dwl` pattern). **Difference from Jewelry**: Petroleum's AQRs get real values fed in, where Jewelry currently sends `null` for every response field regardless of question (see `transform-assessment-question-response.dwl` — all of `CurrencyValue`/`DateValue`/`IntegerResponseValue`/`ChoiceValue`/`ResponseText` are hardcoded `null`).

Petroleum's question list (order given, replaces Jewelry's 7-question fixed list — implemented in `transform-assessment-question-response-petroleum.dwl`):
| # | Question | Value |
|---|---|---|
| 1 | PET Name on Vehicle Different | hardcoded `false` (like Jewelry's nulls) — **Correction**: `ChoiceValue` on `AssessmentQuestionResponse` expects a String, not a raw Boolean; sending `false` as a DataWeave Boolean threw a Java `ArrayStoreException` (`arraycopy: element type mismatch ... to the type ... java.lang.String`) from the Salesforce connector's batch-create marshaling. Jewelry never hit this because it always sends `ChoiceValue: null`. Fixed in `transform-assessment-question-response-petroleum.dwl`: `ChoiceValue: if (q.choiceValue != null) q.choiceValue as String else null` |
| 2 | PET Name on Vehicle | `null` for all (like Jewelry) |
| 3 | PET Insurance Company | `MercStd.insurance_company` |
| 4 | PET Policy Expiration | `MercStd.ins_expire_date` |
| 5 | PET Date App Received | `MercStd.date_issued` |
| 6 | PET_Delivery_Vehicles | JSON string built by `transform-vehicles-petroleum.dwl` (see below) |

### Petroleum-specific transforms (new files, Jewelry's originals untouched)
Everything not listed here (`transform-address.dwl`, `transform-location-results.dwl`, `transform-invoice.dwl`, `transform-payment.dwl`, etc.) is unchanged from Jewelry and reused as-is.

- **`transform-account-petroleum.dwl`** — replaces `transform2-account.dwl`; only `RecordTypeId`, `Name` (← `compname`), `DBA_Name__c` (← `respparty`), and the `Billing*` fields are populated — see Account/Contact mismatch note above.
- **`transform-contact-petroleum.dwl`** — replaces `transform-contact.dwl`; single structured contact (`contact_fname`/`contact_mi`/`contact_lname`/`contact_area_code`+`contact_telephone`/`email_addr`), hardcoded `Title: "Petroleum"`, only created when `contact_fname` or `contact_lname` is non-blank — see mismatch note above.
- **`transform-account-status-petroleum.dwl`** — replaces `transform-account-status.dwl`; same oldest-`deposit_date` logic, matched by `licenseno` instead of `jobno`.
- **`transform-location-petroleum.dwl`** — same as `transform-location.dwl`, `Description` literal changed from `"Jewelry "` to `"Petroleum "`, and reads `"...Address for License No " ++ licenseno` instead of `"...Job No " ++ jobno` (MercStd has no jobno — see the no-jobno note above).
- **`transform-partyaddress-petroleum.dwl`** — replaces `transform-partyaddress.dwl`; `Effective_From__c` reads `date_issued` instead of `issue_date` (MercStd has no `issue_date` — see issue-date note above).
- **`transform-bla-petroleum.dwl`** — differs from `transform-bla.dwl` in several fields:
  - `Trade__c` — hardcoded to `"TBD"` placeholder (real value not yet decided — see dev question #9).
  - `ApplicationType` — hardcoded to `"New"` (2026-07-15; no jobno to derive New/Renewal from, unlike Jewelry — dev question #11 resolved).
  - `Description` reads `"Legacy License Number: " ++ licenseno` instead of `"Legacy Job Number: " ++ jobno`.
  - `AmountPaid` — **not** hardcoded to `0` like Jewelry. Business rule: the `tot_pymt_amt` from the `MercAR` (AR) record with the **max** `deposit_date`, matched by `licenseno`. Implemented by filtering `vars.mercArRows` (Petroleum's pre-parsed AR rows, same "parse once upfront" pattern as Jewelry's `vars.arRows` — see section 2's Flow Structure and section 5, but deliberately named `mercArRows` to keep it distinct) to `licenseno` matches, then taking the row with the latest `deposit_date` — mirror image of `transform-account-status.dwl`'s oldest-date logic (section 5), just `[-1]` (last, since `orderBy` is ascending) instead of `[0]`.
  - `Status` — **not** hardcoded to `"Approved"` like Jewelry's `transform-bla.dwl`. Business rule (2026-07-15): if `vars.row.SourceFileType == "Current"`, then `"Approved"` if any of that `licenseno`'s `MercAR` rows (`matchingArRows`, the same filtered set `AmountPaid` uses) has a `deposit_date` whose year is **2026** (hardcoded literal, not derived from `now()` — this is a one-time cutover load), else `"Draft"`; if `SourceFileType == "Historical"`, always `"Approved"`. This is `Business_License_Application__c.Status`, distinct from `transform-business-license-petroleum.dwl`'s `RegulatoryAuthorization.Status` (Active/Inactive, driven directly by `SourceFileType` alone — see below), which is unchanged.
  - `Policy_Expiration_Date__c` (new field, 2026-07-15) = `ins_expire_date`, parsed `M/d/yyyy`. **Moved here from `transform-business-license-petroleum.dwl`'s `Insurance_Policy_Expiration_Date__c`** — that field turned out to be a formula field on `BusinessLicense`/RegulatoryAuthorization, not settable via the connector, so the same rule was re-applied to `Business_License_Application__c.Policy_Expiration_Date__c` instead. `ins_expire_date` is the field already confirmed to hit the Access `0:00:00` export issue (see the date-columns note above) — should already be clean if `MercStd.ins_expire_date` was retyped to Short Text as documented there. **Two corrections en route**: (1) unlike this project's other Petroleum date fields (`Issue_Date__c`, `Expiration_Date__c`, `PeriodStart`/`PeriodEnd`), which are all `DateTime` and get the `as DateTime {format: "yyyy-MM-dd'T'HH:mm:ssX"}` treatment, `Policy_Expiration_Date__c` is a plain **`Date`** field — sending a `DateTime`-shaped value threw `value not of required type`. (2) even after switching to a bare `Date {format: "M/d/yyyy"}` parse, the non-padded original format (e.g. `9/7/2025`) carried through and was still rejected — the `Date` coercion retains the parse format's metadata unless explicitly re-formatted. Fixed the same way the `DateTime` fields already do it: reformat through an intermediate zero-padded `String {format: "yyyy-MM-dd"}`, then re-coerce that string back `as Date {format: "yyyy-MM-dd"}` — `(insExpireDate as Date {format: "M/d/yyyy"} as String {format: "yyyy-MM-dd"}) as Date {format: "yyyy-MM-dd"}`.
- **`transform-business-license-petroleum.dwl`** — replaces `transform-business-license.dwl`; `date_issued` instead of `issue_date`, `licenseno` instead of `jobno` throughout (`Name: "PET-" ++ licenseno` — confirmed prefix is `"PET-"`, not Jewelry's `"CS-"`, `Legacy_License_Number__c: licenseno`), `Status` still driven by `vars.row.SourceFileType` (confirmed present, see SourceFileType note above).
  - **`Expiration_Date__c`/`PeriodEnd` rule change (2026-07-15)**: no longer derived from `date_issued` (was: last day of the month before issue-month, +1 year — Jewelry's rule, originally copied over for Petroleum too). Now: **7/31 of the year after `license_issued`** — `license_issued` is a separate `MercStd` column holding just a year (e.g. `2026` → expiration `7/31/2027`), not the same field as `date_issued`. Same Access-numeric-column `.0`-stripping treatment (`splitBy "."`) applied before parsing, since `license_issued` exports the same way as other numeric Access columns (see the recurring `.00` artifact note above). `Issue_Date__c` is unaffected — still driven by `date_issued`.
  - **`PeriodStart` rule change (2026-07-15)**: no longer the same value as `Issue_Date__c` (was `date_issued`-derived, matching Jewelry). Now **8/01 of `license_issued`'s own year** (not +1 — confirmed: same year as `license_issued` itself, e.g. `license_issued` `2026` → `PeriodStart` `8/1/2026`, paired with `PeriodEnd`/`Expiration_Date__c` `7/31/2027`, giving a normal Aug-to-Jul one-year license period). `Issue_Date__c` still reads `date_issued` unchanged — the two fields are now fully decoupled.
  - **New field (2026-07-15)**: `Insurance_Company__c` = `insurance_company` (plain passthrough, no parsing). A matching `Insurance_Policy_Expiration_Date__c` was also attempted here but turned out to be a **formula field** on `BusinessLicense`/RegulatoryAuthorization, not settable via the connector — moved to `transform-bla-petroleum.dwl`'s `Policy_Expiration_Date__c` instead, see that bullet above.
  - **`Name` number part is zero-padded to 7 digits** (2026-07-15): `licenseno` `123` → `Name: "PET-0000123"`, not `"PET-123"`. Implemented manually (`"0000000" ++ licenseno` then slice the last 7 chars via `sizeOf`-computed indices) rather than a stdlib pad function like `leftPad`. At the time this was written, the `some` call in `transform-bla-petroleum.dwl`'s Status logic had just failed with an unqualified call and no `import` — later diagnosed (see the ContentNote Base64 note in section 6) as needing an explicit `import * from dw::core::Arrays`/`dw::core::Strings`, not that these modules are unusable. **Revise if touching this again**: `licenseno as String` padded via `import leftPad from dw::core::Strings` would likely work fine now — this manual version isn't required, just untouched since it already works.
- **`transform-assessment-petroleum.dwl`** — replaces `transform-assessment.dwl`; `date_issued` instead of `issue_date`, and `Name: "Universal License Assessment"` instead of Jewelry's `"Business License Assessment"`.
- **`transform-vehicles-combine.dwl`** — joins the `01`/`02` truck file pairs on `licenseno` into one row per license; reused once for the Current pair and once for the Historical pair (see Vehicles Flow Structure above).
- **`transform-contentnote-petroleum.dwl`** (new file, 2026-07-15) — builds `ContentNote` (standard object, no `__c`): `Title: "Petroleum Conversion"`, `Content` = raw HTML string built from `vars.row` (`certificate`, `certif_dmv`, `certif_gu`, `comments`), 4 `<p>` tags — `"Certificate: " ++ certificate`, `"Certificate (DMV): " ++ certif_dmv`, `"Certificate GU: " ++ certif_gu`, `"Comments: " ++ comments`.
  - **No Base64 encoding needed** (confirmed 2026-07-15) — `ContentNote.Content` is a rich-text field; the Salesforce connector encodes it automatically. Manually Base64-encoding the HTML (three attempts: `String`↔`Binary` coercion with `{encoding: "base64"}`, `write(html, "application/base64")`, and finally `dw::core::Binaries::toBase64`) actually produced **double**-encoded Base64 text visibly showing up *inside* the note in Salesforce; sending plain HTML directly rendered correctly. Lesson: don't assume a Content/rich-text field needs manual encoding just because the field name or API docs suggest it — test with the raw value first.
- **`transform-contentdocumentlink-petroleum.dwl`** (new file, 2026-07-15) — builds `ContentDocumentLink`: `ContentDocumentId: vars.contentNoteId` (Id from the just-created ContentNote), `LinkedEntityId: vars.blaId`, `ShareType: "V"`, `Visibility: "InternalUsers"`. Gated on `vars.contentNoteId != null` (Choice, same failed-parent-skip pattern as Business License/Assessment being gated on `blaId`), nested inside `AddBusinessLicenseAppPetroleum` after the AQR step — see Flow Structure above.
- **`transform-vehicles-petroleum.dwl`** — builds the `PET_Delivery_Vehicles` JSON string (see shape above) from `vars.truckRows` filtered to the current `vars.row.licenseno`. Output of a dedicated Transform Message step, stored as `vars.deliveryVehiclesJson`, ahead of the AQR transform — same "compute once, stash in a var" shape as `vars.aqvMap`/`vars.mercArRows`.
- **`transform-assessment-question-response-petroleum.dwl`** — Petroleum's version of `transform-assessment-question-response.dwl`, 6-question list instead of Jewelry's 7, with real values instead of all-null (see AQR mapping above). Date fields assume `M/d/yyyy` format, same unconfirmed assumption as `transform-bla-petroleum.dwl`'s `deposit_date`.
- **`transform-ar-lookup-petroleum.dwl`**, **`transform-invoiceline-petroleum.dwl`**, **`transform-payment-petroleum.dwl`** — `AddInvoicesPetroleum`'s licenseno-keyed equivalents of `transform-ar-lookup.dwl`/`transform-invoiceline.dwl`/`transform-payment.dwl` (see AddInvoicesPetroleum sub-flow above); `transform-invoice.dwl` itself is reused unchanged.

### Open items
- `Trade__c` value for Petroleum — logged as dev question #9.
- `registrationExpiry` real source/value for `PET_Delivery_Vehicles` — logged as dev question #10.
- `ApplicationType` (New/Renewal) — no jobno to derive it from, logged as dev question #11.
- Whether `MercStd`/`MercAR`'s date columns (`deposit_date`, `ins_expire_date`, `date_issued`) match Jewelry's `LaborAR.csv` format (`M/d/yyyy`, non-padded — see section 3's Date Format note) needs confirming once real data is available; `transform-bla-petroleum.dwl` and `transform-assessment-question-response-petroleum.dwl` currently assume they do. **Update**: `MercAR.deposit_date`, `MercStd.date_issued`, and `MercStd.ins_expire_date` confirmed to hit the same `0:00:00` Access export issue as Jewelry (see date columns note above) — all three fixed by retyping the Access column to Short Text; `MercAR`'s `check_date`/`mo_ord_date`/`cash_pymt_date` still need individual confirmation.
- **Needs verification in Studio**: confirm the CSV reader picks up headers correctly for all 4 truck files (`header: true`) and that `licenseno` comes through as the same type/format across `TrucksReg01`/`02`/`TrucksHis01`/`02` and `MercStd`/`MercAR` for the join/filter to match reliably.
- ~~No jobno anywhere in Petroleum means Jewelry's `AddInvoices`/`blaJobnoLog` join needs a licenseno-keyed equivalent~~ — done. Built and confirmed working in Studio as `AddInvoicesPetroleum` (see sub-flow above, `blaLicenseLog`-keyed).
- Contact `Phone` format (`area_code-telephone`) is an unconfirmed assumption — no existing convention elsewhere in the codebase to match (Jewelry's Contact never sets Phone).
- `vars.licenseTypeId` — dev question #1 still open; a stopgap Query + Set Variable was added in Studio before the BLA transform (both Jewelry and Petroleum) to unblock testing in the meantime.
- **TODO**: merge Historical into Current for `MercStd`/`MercAR` (i.e. `MercStdHis` → `MercStd`, `MercARHis` → `MercAR`), with `SourceFileType` set appropriately per row — the Access-side step that produces the final `SourceFileType`-tagged `MercStd.csv`/`MercAR.csv` Mule actually reads (see SourceFileType note above) hasn't been done yet.

---

## 7. Next Work Unit: BiWeeklyPayroll (Planned)

**Correction**: this section previously assumed BiWeekly would load Invoice__c/InvoiceLine__c/Payment__c like Jewelry/Petroleum, with a single-file simplification to the join logic. **Confirmed otherwise**: BiWeeklyPayroll does **not** load Invoice__c, InvoiceLine__c, or Payment__c at all — those three objects are simply out of scope for this work unit, not simplified. Everything below in this section needs to be redone with that in mind; the "single file, one row per job" simplification reasoning may still be relevant for whatever objects *are* in scope, but the Invoice/Payment-specific parts of the old write-up no longer apply.

Target objects (most of the same set as Jewelry/Petroleum, minus Invoice__c/InvoiceLine__c/Payment__c): Account, Location/Address__c/PartyAddress__c, Contact, Business License Application, Business License, Assessment/Assessment Question Response, Account_Status__c. Source data is **a single input file**.

### Source file — `BiWeeklyPayroll.csv` (confirmed 2026-07-10)
Single file, one row per license application, keyed by `RID` (int) — confirms the one-row-per-job grain, so `Account_Status__c`/BLA dates can read straight off the row with no `arRows`-style join.

Full column list:
`RID, CompanyName, CompanyAddr, CompanyCity, CompanyState, CompanyZip, CompanyTel, Email, CompanyContact, CompanyContactTitle, CorpOfficeAddr, CorpOfficeCity, CorpOfficeState, CorpOfficeZip, CorpOfficeTel, CompanyNameSecState, RIagentName, RIagentAddr, RIagentCity, RIagentState, RIagentZip, RIagentTel, CompanyFEIN, MethodPaid, PayDay, ClassificationInvolved, SalaryRangeInvolved, WageHrViol, TypAppl, DateRecd, DateApproved, DateDenied, DateExpired, DateRevoked, ReviewedBy, Proof200Missing, ProofHighestBiWeeklyMissing, ConsentColBargMissing, MethodPaidMissing, PayDayMissing, ClassificationMissing, SalaryRangeMissing, CertNoWageHrViolMissing, OtherMissing, OrigSigChk, SuretyBondChk, PayrollRecChk, ConsentColBargChk, PayrollRec200Chk, MethodPaidChk, PayDayChk, ClassificationChk, SalaryRangeChk, CertNoWageHrViolChk, DateRenewed, DateRecd_validation, DateApproved_validation, DateDenied_validation, DateExpired_validation, DateRevoked_validation, DateRenewed_validation, CompanyZip_validation, CorpOfficeZip_validation, RIagentZip_validation, Email_validation, missing_percentages_%`

**Working hypothesis on the checklist columns** (unconfirmed — needs user sign-off before transforms are written): the `*Missing`/`*Chk` columns appear to pair up into a review checklist, one pair per required-document/data item:
- `MethodPaid`/`MethodPaidMissing`/`MethodPaidChk`, `PayDay`/`PayDayMissing`/`PayDayChk`, `ClassificationInvolved`/`ClassificationMissing`/`ClassificationChk`, `SalaryRangeInvolved`/`SalaryRangeMissing`/`SalaryRangeChk` — a raw value plus "is it missing" plus "was it checked by reviewer" for each.
- `WageHrViol`/`CertNoWageHrViolMissing`/`CertNoWageHrViolChk` — same pattern, but the value field's name doesn't match the Missing/Chk suffix (`WageHrViol` vs `CertNoWageHrViol...`), so this pairing is a guess, not confirmed.
- `Proof200Missing`/`PayrollRec200Chk`, `ProofHighestBiWeeklyMissing`/`PayrollRecChk` — possible pairings, also unconfirmed (names don't match as cleanly).
- `ConsentColBargMissing`/`ConsentColBargChk`, `OrigSigChk`, `SuretyBondChk`, `OtherMissing` — checklist-only items with no separate value field.
- If confirmed, this checklist likely maps to Assessment Question Response the same way Petroleum's 6-question list did — but the exact question wording/count is not yet known.

**Other new columns**: `DateRenewed` — a sixth status-shaped date, needs to be added to the Account_Status__c precedence question. **Confirmed (2026-07-12): `*_validation` columns (`DateRecd_validation` … `Email_validation`) and `missing_percentages_%` are QA-only** — Access-side data-quality metadata, not read by any transform, not loaded to Salesforce.

Notable shape differences from Jewelry/Petroleum, not yet mapped to Salesforce objects/fields — **do not guess**, confirm with the user before writing transforms:
- Two addresses per row (`Company*` and `CorpOffice*`) plus a third contact-like block (`RIagentName/Addr/City/State/Zip/Tel` — registered agent) — unclear how many PartyAddress__c/Contact records this produces, unlike Jewelry's up-to-4 respparty pattern or Petroleum's single structured contact.
- `CompanyNameSecState` — likely a Secretary-of-State-registered name distinct from `CompanyName`, meaning unclear.
- `TypAppl` — unlike Petroleum (which had no application-type field at all, hardcoded "TBD"), BiWeeklyPayroll appears to have a real application-type field. Actual values not yet known.
- Five status-shaped dates (`DateRecd, DateApproved, DateDenied, DateExpired, DateRevoked`) plus `ReviewedBy` — this is a materially different BLA/Account_Status__c status model than Jewelry/Petroleum (which only had an issue date), likely driving Approved/Denied/Revoked/Expired states. Precedence/logic between these fields not yet known.
- `MethodPaid, PayDay, ClassificationInvolved, SalaryRangeInvolved, WageHrViol` — unclear whether these are Assessment Question Response answers (like Petroleum's 6-question AQR list) or unused/reference-only fields.
- `Proof200Missing, ProofHighestBiWeeklyMissing` — look like boolean AQR-style questions, but the actual AQR question names/wording they map to aren't known yet.
- `CompanyFEIN` maps cleanly to Account FEIN (Jewelry/Petroleum precedent).

### Account creation rules (confirmed 2026-07-12)
- One Account per source row (`RID`), same as Jewelry/Petroleum's one-per-grain-key pattern.
- **Hardcoded skip**: `RID` 550 and 551 are excluded if present — no Account (or anything else) created for those rows.
- **`DateRecd` null/empty → skip the whole record**, not just Account — log a note but do not import. (Unlike Jewelry/Petroleum, where every row got created regardless of date fields.) **Only the Account-creation skip gets logged** — downstream objects (Contacts, Addresses, BLA, etc.) aren't separately logged as skipped, they just never get created since there's no Account to attach to (same cascade-by-omission pattern as any other row that fails earlier in the `For Each`).
- **`CompanyFEIN` null/empty → still import**, but log a note. FEIN is not a gate, unlike `DateRecd`.
- No other conditional logic on Account creation beyond these three rules.

**Correction (2026-07-12)**: the "invalid `Email` → empty string" rule given alongside the above actually belongs to **Contact**, not Account — Account has no Email field in this mapping. Applies once Contact's field mapping is designed.

**Skip/note logging (confirmed 2026-07-12)**: `DateRecd`-null skips and `CompanyFEIN`-null notes don't fit the existing Result & Log Pattern (section 2), which only fires after a Salesforce Create — instead they're appended to the same `vars.logEntries` array at the filter step, before the `For Each` even starts, so everything still lands in one `import_log.csv`:
- Skip: `{RID: row.RID, object: "Account", status: "Skipped", salesforce_id: null, error_code: null, error_message: "DateRecd missing - record not imported"}`
- Note: `{RID: row.RID, object: "Account", status: "Note", salesforce_id: null, error_code: null, error_message: "CompanyFEIN missing"}` — appended in addition to (not instead of) the normal Success/Failed entry `AddAccount` logs after the real Create call.

Built `transform-filter-and-name-biweeklypayroll.dwl` (new file) implementing the `RID` 550/551 hard skip, the `DateRecd`-null skip+log, and the `CompanyFEIN`-null note — same shape as Petroleum's `transform-filter-and-name-petroleum.dwl` but returns `{rows: [...], logEntries: [...]}` instead of a bare row array, since this is the first work unit that needs to produce log entries before the main `For Each` starts. `RID` is normalized the same way `jobno`/`licenseno` were (strip a trailing `.0` Access-export artifact via `splitBy "."`) before comparing against `"550"`/`"551"` or using it as the row's key.

### Account field mapping (confirmed 2026-07-12)
RecordType: Business Account, populated via a query-based `InitAccountRecordTypeBiWeeklyPayroll` sub-flow (same approach as Petroleum, **not** Jewelry's hardcoded `RecordTypeId`):
```
Salesforce Query: SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account'
Set Variable: accountRecordTypeId = #[payload[0].Id]
```
Run once at flow start, same as Petroleum's `InitAccountRecordTypePetroleum` (section 6).

| Salesforce field | Source | Notes |
|---|---|---|
| `RecordTypeId` | `vars.accountRecordTypeId` | From `InitAccountRecordTypeBiWeeklyPayroll`, see above |
| `Name` | `CompanyName` | |
| `Federal_Tax_ID__c` | `CompanyFEIN` | Reuses Jewelry's `fixFein` cleanup (strips dashes, reformats 9-digit to `XX-XXXXXXX`) |
| `DBA_Name__c` | — | Hardcoded `""` (literal empty string) — unlike Jewelry (`company`) and Petroleum (`respparty`), BiWeeklyPayroll has no separate DBA-like field |
| `Business_Entity_Type__c` | — | Hardcoded `"Customer"` — not a lookup like Jewelry's `businessEntityTypes` map (`bustype` → Sole Proprietorship/Corporation/etc.); BiWeeklyPayroll has no equivalent source field |
| `BillingStreet` | `CompanyAddr` | Single field, no add1/add2 concat needed (no separate address-line-2 column in this file) |
| `BillingCity` | `CompanyCity` | |
| `BillingState` | `CompanyState` | Same `stateNames` 2-letter→full-name lookup table as Jewelry/Petroleum (`transform2-account.dwl`/`transform-account-petroleum.dwl`), fallback to raw value if not found |
| `BillingPostalCode` | `CompanyZip` | |
| `Preferred_Method_of_Comm__c` | — | Hardcoded `"Mail"` (2026-07-15) — same for all three units (Jewelry `transform2-account.dwl`, Petroleum `transform-account-petroleum.dwl`, BiWeeklyPayroll `transform-account-biweeklypayroll.dwl`); no source field, new Account field added across all three at once |

Built `transform-account-biweeklypayroll.dwl` (new file) implementing this — `fixFein` and `stateNames` duplicated in-file, same pattern as Petroleum's copy in `transform-account-petroleum.dwl`.

Not yet covered here: `RIagent*` block (still open — likely a Contact, not confirmed).

### Location / Address__c field mapping (confirmed 2026-07-12/13)
Unlike Jewelry/Petroleum's Mailing/Physical PO-Box-driven split, BiWeeklyPayroll always creates **exactly two** Location/Address__c pairs per row, sourced from two different address blocks:

**Location 1 — "Company"** (from `Company*`):
| Field | Value |
|---|---|
| `LocationType` | `"Business Site"` |
| `Name` | `"Company"` |
| `Description` | `"Bi-Weekly address for RID " ++ RID` |

**Address 1** (`ParentId` = Location 1's Id):
| Field | Value |
|---|---|
| `LocationType` | `"Business Site"` |
| `ParentId` | `locationId` |
| `Street` | `CompanyAddr` |
| `City` | `CompanyCity` |
| `StateCode` | `CompanyState` |
| `PostalCode` | `CompanyZip` |
| `Country` | `"United States"` (matches Jewelry/Petroleum's `Country`/`"United States"` pattern — **not** a `CountryCode`/`"US"` field, corrected 2026-07-13) |

**Location 2 — "Corporate"** (from `CorpOffice*`, corrected 2026-07-13 — user's first pass said `Name = "Company"` for this one too, confirmed should be `"Corporate"`):
| Field | Value |
|---|---|
| `LocationType` | `"Business Site"` |
| `Name` | `"Corporate"` |
| `Description` | `"Bi-Weekly corporate address for RID " ++ RID` |

**Address 2** (`ParentId` = Location 2's Id):
| Field | Value |
|---|---|
| `LocationType` | `"Business Site"` |
| `ParentId` | `locationId` |
| `Street` | `CorpOfficeAddr` |
| `City` | `CorpOfficeCity` |
| `StateCode` | `CorpOfficeState` |
| `PostalCode` | `CorpOfficeZip` |
| `Country` | `"United States"` |

**`AddressType`/`Address_Type__c` confirmed (2026-07-13)**: both Locations get `"Physical"` for now — user's words: "that may change later," so treat as a placeholder, not a final business rule. This means `AddressType` is no longer what distinguishes "Company" from "Corporate" the way `"Mailing"`/`"Physical"` did in Jewelry/Petroleum — that distinction is now carried by `Location.Name`/`vars.locationName` instead ("Company" vs "Corporate"), used purely to pick which source columns (`Company*` vs `CorpOffice*`) feed the Address.

Built three new transforms:
- `transform-location-biweeklypayroll.dwl` — always returns both Locations (no PO-Box-driven conditional like Jewelry/Petroleum), `Description` uses `RID` instead of `jobno`/`licenseno`.
- `transform-location-results-biweeklypayroll.dwl` — BiWeeklyPayroll equivalent of `transform-location-results.dwl`; returns `locationName` (`Location.Name`, "Company"/"Corporate") instead of `addressType`, since the picklist value no longer varies. In Studio, the inner `For Each` sets `vars.locationName` from this and separately sets `vars.addressType = "Physical"` as a hardcoded constant (not derived).
- `transform-address-biweeklypayroll.dwl` — branches `Street`/`City`/`StateCode`/`PostalCode` on `vars.locationName == "Company"` (→ `Company*` columns) vs. else (→ `CorpOffice*` columns); `AddressType` is `vars.addressType` (the hardcoded `"Physical"`); `Country: "United States"` (confirmed, not `CountryCode`).

**`transform-partyaddress-biweeklypayroll.dwl` confirmed (2026-07-13) and built**: `Effective_From__c` derives from `DateRecd` (`M/d/yyyy` format, confirmed correct). `Is_Primary__c` is `vars.locationName == "Company"` (Company is primary, Corporate is not). `PartyId`/`AddressId__c`/`Address_Type__c` unchanged from the existing pattern.

**Confirmed (2026-07-13): `DateRecd` hit the same Access `0:00:00` export artifact as `MercAR`/`MercStd`'s date columns** (section 6) — fixed the same way, retyping the Access column to Short Text.

**Update (2026-07-14): `DateApproved`, `DateDenied`, `DateExpired`, `DateRevoked`, and `DateRenewed` all retyped to Short Text in Access**, same fix, ahead of testing BLA/BusinessLicense. All six status-shaped date columns (`DateRecd` included) are now confirmed clean of the `0:00:00` export artifact.

### Location/Address/PartyAddress Flow Structure (nested inside `AddLocationsAndAddressesBiWeeklyPayroll`, same shape as Jewelry/Petroleum section 2/6)
```
Flow Reference: AddLocationsAndAddressesBiWeeklyPayroll
  → Transform Message (transform-location-biweeklypayroll.dwl — always 2 items, "Company"/"Corporate")
  → Set Variable: locationList = payload
  → Salesforce Create Location(s): Records = vars.locationList
  → Transform Message (transform-location-results-biweeklypayroll.dwl)
  → Set Variable: locationResults = payload
  → For Each location result: (Collection: #[vars.locationResults])
      → Set Variable: locationId = #[payload.locationId]
      → Set Variable: locationName = #[payload.locationName]
      → Set Variable: addressType = "Physical"   (hardcoded constant, not derived — see AddressType note above)
      → Choice
          When #[payload.success]:
              → Transform Message (transform-address-biweeklypayroll.dwl)
              → Salesforce Create Address__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "Address__c"]
              → Choice
                  When #[vars.addressId != null]:
                      → Transform Message (transform-partyaddress-biweeklypayroll.dwl)
                      → Salesforce Create PartyAddress__c (Records: #[[payload]]) → [Result & Log Pattern → logEntries, object: "PartyAddress__c"]
                  Otherwise: (skip — Address__c failed)
          Otherwise: (skip — Location failed, log already captured by Location's own Result & Log entry)
```

### Contact field mapping (confirmed 2026-07-13/14)
Two independent Contacts per row (not gated on each other), each skipped entirely if its driving field is blank — same "skip if blank" pattern as Petroleum's single optional contact:

**Company contact** (skipped if `CompanyContact` is blank):
| Field | Source | Notes |
|---|---|---|
| `FirstName`/`MiddleName`/`LastName` | `CompanyContact` | Split via `parseName` — reuses Jewelry's `transform-contact.dwl` word-splitting logic (first word → `FirstName`, last word → `LastName`, everything between → `MiddleName`), minus the title-stripping half (Title comes from a real column here, not extracted from the name) |
| `Email` | `Email` | Invalid-format-→-empty-string rule applies here (confirmed 2026-07-13 this belongs to Contact, not Account) — validated against `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`, blanked if it doesn't match |
| `Title` | `CompanyContactTitle` | |
| `AccountId` | `vars.accountId` | |
| `Phone` | — | **Not set** for this contact — confirmed 2026-07-13, Phone only applies to the RI contact below |

**RI contact** (skipped if `RIagentName` is blank):
| Field | Source | Notes |
|---|---|---|
| `LastName` | `RIagentName` | **No parsing** — unlike the Company contact, `RIagentName` is often a company name rather than a person's name, so the whole value goes to `LastName` as-is, no `FirstName`/`MiddleName` split |
| `Title` | — | Hardcoded `"RI Agent"` |
| `AccountId` | `vars.accountId` | |
| `Phone` | `RIagentTel` | Defaults to `"(999) 999-9999"` if blank |

Built `transform-contact-biweeklypayroll.dwl` implementing both. `RIagentAddr/City/State/Zip` are **not used** — no address is created for the RI agent, only `RIagentName`/`RIagentTel` feed Salesforce.

### Contact Flow Structure (`AddContactsBiWeeklyPayroll`, independent — no downstream gating, same as Jewelry/Petroleum's `AddContacts`)
```
Flow Reference: AddContactsBiWeeklyPayroll
  → Transform Message (transform-contact-biweeklypayroll.dwl — 0-2 items)
  → Salesforce Create Contact(s): Records = #[payload]   (no intermediate `contactList` variable needed —
      unlike Location, nothing downstream needs to look back at the original records; matches Jewelry's
      actual AddContacts pattern, which also skips this)
  → Transform Message (extract results, List Result & Log Pattern) → Set Variable: contactResults = payload
  → Set Variable: logEntries = (vars.logEntries default []) ++ (vars.contactResults map (r) -> {
        RID: vars.row.RID, object: "Contact", status: if (r.success) "Success" else "Failed",
        salesforce_id: r.id, error_code: r.errorCode, error_message: r.errorMessage
    })
```

### BLA (Business License Application) — confirmed rules so far (2026-07-14)

**`ApplicationType`** (from `TypAppl`):
| `TypAppl` value | `ApplicationType` |
|---|---|
| `"Initial"` | `"New"` |
| `"Re-application"` | `"Renewal"` |
| anything else (including blank) | `"Initial"` |

**`Status`** — unlike Jewelry/Petroleum's hardcoded `"Approved"`, BiWeeklyPayroll derives it from the five status dates:
1. `"Submitted"` if `DateRecd` is non-null **and** `DateApproved`/`DateDenied`/`DateExpired`/`DateRevoked`/`DateRenewed` are **all** null.
2. `"Denied"` if `DateRecd` is non-null, `DateApproved` is null, `DateExpired` is null, **and** `DateDenied` is non-null. (Rule as given doesn't reference `DateRevoked`/`DateRenewed` at all — implemented literally, not inferring additional conditions on those two.)
3. Otherwise: `"Approved"`.

**Also confirmed (2026-07-14)**: `AppliedDate` ← `DateRecd`. `AmountPaid` hardcoded `0` (same as Jewelry, no AR/payment file here). `Trade__c` is `null` for now (placeholder, unlike Petroleum's still-open "TBD" — this one's deliberately null, not pending an answer).

**Also confirmed (2026-07-14)**: BLA `Description` = `"Legacy RID: " ++ RID`. `Legacy_License_Number__c` = `RID`. Business License `Name` = `"BW-" ++ RID` (BiWeeklyPayroll's prefix, alongside Jewelry's `"CS-"` and Petroleum's `"PET-"`).

**Business License date/status logic confirmed (2026-07-14)** — no computed one-year expiration like Jewelry/Petroleum; reads directly off the real status dates instead:
- `Issue_Date__c` = `PeriodStart` = the **later** of `DateApproved`/`DateRenewed` (null-safe: if only one is set, use it; if both null, result is null).
- `PeriodEnd` = the **later** of `DateExpired`/`DateRevoked` (same null-safe logic).
- `Expiration_Date__c` = hardcoded `null` — not derived at all for this unit.
- `Status` (Active/Inactive equivalent) = `"Verified"` if `DateExpired` is null **or** today's date is before `DateExpired`; otherwise `"Inactive"`. Independent of BLA's own `Status` derivation — not reused.

Built `transform-bla-biweeklypayroll.dwl` and `transform-business-license-biweeklypayroll.dwl` implementing all confirmed BLA/BusinessLicense rules. `transform-business-license-biweeklypayroll.dwl` introduces a null-safe `laterDate(a, b)` helper (parses both with `M/d/yyyy`, returns whichever is later, falls back to whichever one is non-null, or `null` if both are) — first use of this pattern on the project, since Jewelry/Petroleum never needed to compare two dates against each other.

### BLA/BusinessLicense Flow Structure (nested inside `AddBusinessLicenseAppBiWeeklyPayroll`, same shape as Jewelry/Petroleum section 2/6)
```
Flow Reference: AddBusinessLicenseAppBiWeeklyPayroll
  → Transform Message (transform-bla-biweeklypayroll.dwl)
  → Salesforce Create Business License Application (AccountId = accountId, Records: #[[payload]])
      → [Result & Log Pattern → logEntries, object: "BusinessLicenseApplication"; sets blaId]
  → Choice
      When #[vars.blaId != null]:
          → Set Variable: blaRidLog = (vars.blaRidLog default []) ++ [{ RID: vars.row.RID,
              blaId: vars.blaId, accountId: vars.accountId }]
          → Transform Message (transform-business-license-biweeklypayroll.dwl)
          → Salesforce Create Business License (Records: #[[payload]])
              → [Result & Log Pattern → logEntries, object: "BusinessLicense"]
      Otherwise: (skip — BLA failed, Business License/Assessment/AQR not attempted)
```
Note: unlike Jewelry/Petroleum, there's no `AddInvoices`-equivalent needing `blaRidLog` later (Invoice__c/Payment__c out of scope, see the correction at the top of this section) — but the log is still useful for the eventual Note object (details TBD) and general audit/debugging, so it's kept.

**Naming note (2026-07-14)**: this variable is called `blaRidLog` (RID-keyed), deliberately distinct from Jewelry's `blaJobnoLog` and Petroleum's `blaLicenseLog` — same "keep each work unit's variable names distinct even when the shape is identical" preference already established between Jewelry and Petroleum.

### Assessment Question Response — question list confirmed (2026-07-14), field mapping still open
13 questions total (vs. Jewelry's 7, Petroleum's 6). The full sentences below are the **question wording** (for readability in this doc only) — **corrected 2026-07-14**: the actual `AssessmentQuestionVersion.Name` value used in `WHERE Name IN (...)` and the transform's `aqvMap` lookup key is the short label in parens, not the full sentence (the user's first pass gave the full sentences as the `Name` values, which was wrong — `Name` is a short label, `QuestionText` is the full sentence, and the SOQL/transform were querying/looking up on the wrong one):

1. Does the company's average payroll exceed 200% of State minimum wage? (`Name`: "Avg Payroll Exceed 200")
2. Did the company have payroll during the entire last calendar year? (`Name`: "Company Payroll")
3. Estimated Biweekly Wages (`Name`: "Estimated Wages")
4. Payment Method (`Name`: "Payment Method")
5. Payment Day (`Name`: "Payment Day")
6. Employee Class (`Name`: "Employee Class")
7. Salary Min (`Name`: "Salary Min")
8. Salary Max (`Name`: "Salary Max")
9. Bond Value (`Name`: "Bond Value")
10. Bond Expiration Date (`Name`: "Bond Expiration Date")
11. Has said company ever had a wage and hour violation? (`Name`: "Pay Violation")
12. Are the involved employees subject to collective bargaining? (`Name`: "Collective Bargaining")
13. Date Application Received (`Name`: "Date App Received")

**Per-question field mapping (confirmed so far, gathered one at a time, 2026-07-14)**:
| # | Question | ResponseType | Value |
|---|---|---|---|
| 1 | Payroll exceeds 200% of min wage? | `Long Text Area` | `ResponseText: if ((PayrollRec200Chk default "") == "Yes") "Yes" else "No"` — confirms `PayrollRec200Chk` feeds this question (not `Proof200Missing`, which was the earlier unconfirmed guess). **Corrected 2026-07-14**: originally recorded as a literal boolean truthy check; confirmed all `*Chk`/Access "Yes/No"-type columns export as `"Yes"`/`"No"` text, so this needed the same explicit string comparison as Q11/Q12, not `if (PayrollRec200Chk)` |
| 2 | Payroll entire last calendar year? | `Long Text Area` | `ResponseText: if ((PayrollRecChk default "") == "Yes") "Yes" else "No"` — confirms `PayrollRecChk` feeds this one, same correction as Q1 |
| 3 | Estimated Biweekly Wages | `Integer` | `IntegerResponseValue: 0` — hardcoded placeholder, **not** sourced from any column |
| 6 | Employee Class | `Text Area` | `ResponseText: null` — hardcoded placeholder, **not** sourced from `ClassificationInvolved` (that was an unconfirmed guess, now known wrong) |

| 4 | Payment Method | `Text Area` | `ChoiceValue: normalizePaymentMethods(MethodPaid)` — source is `MethodPaid`, run through a ported VB helper (see below); note the field populated is `ChoiceValue`, not `ResponseText`, despite the `Text Area` response type — matches the existing pattern where `responseType` is documentation only, not something the transform branches on |

| 5 | Payment Day | `Text Area` | `ResponseText: normalizeDayValue(PayDay)` — source is `PayDay`, run through a ported VB helper (see below) |

| 7 | Salary Min | `Text Area` | `IntegerResponseValue: getBiweeklySalary(SalaryRangeInvolved, "min")` — see helper below |
| 8 | Salary Max | `Text Area` | `IntegerResponseValue: getBiweeklySalary(SalaryRangeInvolved, "max")` — see helper below |

| 9 | Bond Value | `Text Area` | `ResponseText: null` — hardcoded placeholder, matches Q6's pattern (same ResponseType → same field convention) |
| 10 | Bond Expiration Date | `Text Area` | `ResponseText: null` — hardcoded placeholder, same as Q9 |
| 11 | Wage and hour violation? | `Text Area` | `ResponseText: if ((WageHrViol default "") == "Yes") "Yes" else "No"` — `WageHrViol` can be null, treated as `"No"` |
| 12 | Subject to collective bargaining? | `Text Area` | `ResponseText: if ((ConsentColBargChk default "") == "Yes") "Yes" else "No"` — `ConsentColBargChk` can be null; else-branch **inferred** as `"No"` to match every other Yes/No question's pattern (Q1, Q2, Q11) — user only stated the `"Yes"` condition this time, didn't explicitly restate the else, flag if wrong |
| 13 | Date Application Received | `Text Area` | `DateValue: if ((DateRecd default "") != "") DateRecd as Date {format: "M/d/yyyy"} else null` — native Date field (confirmed, not a text field), same pattern as Jewelry/Petroleum's `DateValue` fields — no output-format string needed, Salesforce handles Date serialization. **Corrected 2026-07-14**: real `AssessmentQuestionVersion.Name` is `"Date App Received"`, not `"Date Application Received"` — same short label Jewelry already uses (`transform-assessment-question-response.dwl`), Petroleum's is `"PET Date App Received"`. This was the actual cause of the missing `aqvMap` key, not a Status/Active issue as first suspected — still need to resolve the DataType Date-vs-DateTime conflict below before this is fully confirmed working |

**All 13 questions now mapped.** Built `transform-assessment-question-response-biweeklypayroll.dwl` — bundles all four ported VB helpers (`normalizePaymentMethods`, `normalizeDayValue`, `safeVal`, `getBiweeklySalary`/`convertToBiweekly`) inline, same "duplicate shared helpers per work unit" pattern as `stateNames`/`fixFein` in the Account transforms.

### InitAssessmentQuestionVersionBiWeeklyPayroll (sub-flow body)
Same pattern as `InitAssessmentQuestionVersion`/`InitAssessmentQuestionVersionPetroleum` (section 2/6) — query all 13 question names, reduce to latest version per question:
```
Salesforce Query: SELECT Id, QuestionText, Name, VersionNumber FROM AssessmentQuestionVersion
                   WHERE (
                       Name IN (
                           'Avg Payroll Exceed 200',
                           'Company Payroll',
                           'Estimated Wages',
                           'Payment Method',
                           'Payment Day',
                           'Employee Class',
                           'Salary Min',
                           'Salary Max',
                           'Bond Value',
                           'Bond Expiration Date',
                           'Pay Violation',
                           'Collective Bargaining'
                       )
                       OR (Name = 'Date App Received' AND VersionNumber = 1)
                   ) AND Status = 'Active'
                   ORDER BY Name ASC, VersionNumber ASC
Transform Message (transform-aqv-lookup.dwl — reused as-is from Jewelry/Petroleum, no BiWeeklyPayroll
  variant needed, it's a generic reduce-by-Name with no work-unit-specific logic)
Set Variable: aqvMap = #[payload]
```
**Correction (2026-07-14)**: this query previously used the full question sentences as `Name` values (matching what `transform-assessment-question-response-biweeklypayroll.dwl`'s `questions` array also had in its `name:` field, used as the `aqvMap` lookup key) — both were wrong. Salesforce's `AssessmentQuestionVersion.Name` is the short label shown above; the full sentence is `QuestionText` (already correctly used for the created `AssessmentQuestionResponse.Name` in the transform's output). Fixed both the SOQL and the transform's `name:` keys to use the short labels. No more apostrophe-escaping concern now that "the company's" isn't in a `Name` value — none of the corrected short labels contain an apostrophe.

**Debugging note (2026-07-14)**: testing showed 12 of 13 `aqvMap` keys resolve correctly; `"Date Application Received"` came back missing, causing `Required_Field_Missing [Name, AssessmentQuestionId]` on that one AQR record (null-safe selector on a missing map key silently returns `null`, same failure shape as the Petroleum `vars.arRows`/`vars.mercArRows` lesson — surfaces downstream, not at the actual cause). **Root cause found**: the real Salesforce `Name` is `"Date App Received"`, not `"Date Application Received"` — a spec-vs-Salesforce mismatch, not a Status/Active issue. Fixed in the SOQL and the transform's `name:` key.

**Resolved (2026-07-14) — pinned to Version 1**: checking Salesforce revealed 4 `AssessmentQuestionVersion` records for `"Date App Received"` — 2 Archived, 2 Active (`VersionNumber` 1 and 2). Version 1's `DataType` is `Date`, Version 2's is `DateTime`. The generic "latest version wins" reduce (`transform-aqv-lookup.dwl`, ordered by `VersionNumber ASC`, each step overwrites) would always resolve to Version 2 (DateTime), conflicting with the earlier-confirmed plain-Date `DateValue`. **Confirmed: pin to Version 1, keep `DateValue` as Date.** Rather than modifying the shared `transform-aqv-lookup.dwl` (used as-is by Jewelry/Petroleum/BiWeeklyPayroll) with BiWeeklyPayroll-specific logic, the SOQL itself now excludes "Date App Received" from the general `Name IN (...)` list and adds a separate `OR (Name = 'Date App Received' AND VersionNumber = 1)` clause — so only one record ever comes back for that Name, and the generic "latest wins" reduce trivially resolves to it (there's no competing Version 2 in the result set to lose to). First work unit needing to pin a specific AQV version instead of blindly taking the latest.

**Resolved (2026-07-14) — Q1/Q2/Q3 fixed, AQR confirmed working end to end**: root cause was a key mismatch between the `questions` array's `name:` values and the actual `aqvMap` keys (not a Salesforce-side `Name` spelling issue — the query was already correct, as the "13 rows returned" evidence indicated). Once the two were made to match exactly, all 13 AQR records create successfully. **All 13 AQR questions confirmed working in Studio.**

### Assessment field mapping (confirmed 2026-07-14) and Flow Structure
| Field | Value |
|---|---|
| `AccountId` | `vars.accountId` |
| `BusinessLicenseApplication__c` | `vars.blaId` |
| `AssessmentStatus` | `"Completed"` |
| `Name` | `"Universal License Assessment"` — same as Petroleum's (both differ from Jewelry's `"Business License Assessment"`) |
| `EffectiveDateTime` | Later of `DateApproved`/`DateRenewed` (same null-safe `laterDate` helper as `transform-business-license-biweeklypayroll.dwl`, duplicated in this file), converted to a `DateTime` string (`yyyy-MM-dd'T'HH:mm:ssX`), matching Jewelry/Petroleum's `EffectiveDateTime` shape |
| `ExpirationDateTime` | `DateExpired`, converted to a `DateTime` string (same `yyyy-MM-dd'T'HH:mm:ssX` shape as `EffectiveDateTime`) — **new field**, not populated by Jewelry/Petroleum's Assessment transforms at all. **Corrected 2026-07-14**: field name is `ExpirationDateTime`, not `ExpirationDate` (was assumed to be a plain Date field; it's actually a DateTime field like `EffectiveDateTime`) |
| `Type` | `"LicensingAndPermitting"` — same as Jewelry/Petroleum |

Built `transform-assessment-biweeklypayroll.dwl` implementing this.

```
  → Transform Message (transform-assessment-biweeklypayroll.dwl)
  → Salesforce Create Assessment (linked to blaId, Records: #[[payload]])
      → [Result & Log Pattern → logEntries, object: "Assessment"; sets assessmentId]
  → Transform Message (transform-assessment-question-response-biweeklypayroll.dwl — uses vars.assessmentId, vars.aqvMap; builds list of 13)
  → Salesforce Create Assessment Question Response (Records: #[payload]) → [List Result & Log Pattern → logEntries, object: "AssessmentQuestionResponse"]
```
`InitAssessmentQuestionVersionBiWeeklyPayroll` needs to be added to the top-level Flow Structure (before the main `For Each`, alongside `InitAccountRecordTypeBiWeeklyPayroll`) — not yet wired into Studio, along with the rest of this Assessment/AQR chain. This is also where the earlier "checklist columns" hypothesis (`*Missing`/`*Chk` pairs) needs to be resolved, since several of these 13 questions plausibly correspond to those raw/missing/checked column triples — though several confirmed above turned out to be hardcoded placeholders rather than column-sourced, so that hypothesis may not hold for the rest either. Don't assume any question maps to a source column without explicit confirmation.

**`getBiweeklySalary`/`convertToBiweekly` helpers (confirmed 2026-07-14, ported from a third client-provided VB script, `GetBiweeklySalary`/`ConvertToBiweekly`)** — parses a free-text salary range string (e.g. `"$15.00 - $18.50/hour"`, `"40000-45000 annual"`), detects pay period (hourly/biweekly/annual) from keywords, strips descriptor text, splits on `-` into min/max, and converts both ends to a biweekly-equivalent integer. Returns `0` on any validation failure (blank input, bad selector, non-positive parsed numbers) — matches the VB `SafeFail` label's behavior exactly, not an error/exception:
```
fun safeVal(s) = do {
    var trimmed = trim(s default "")
    var m = trimmed scan /^-?[0-9]+(?:\.[0-9]+)?/
    ---
    if (isEmpty(m)) 0 else (m[0][0] as Number)
}

fun convertToBiweekly(value, payType) =
    if (payType == "hourly") value * 80
    else if (payType == "biweekly") value
    else if (payType == "annual") value / 26
    else 0

fun getBiweeklySalary(rangeStr, selector) = do {
    var sel = lower(selector default "")
    var raw = rangeStr default ""
    ---
    if (trim(raw) == "" or (sel != "min" and sel != "max")) 0
    else do {
        var c1 = lower(raw)
        var c2 = c1 replace /\$/ with ""
        var c3 = c2 replace "," with ""
        var c4 = c3 replace "+" with ""
        var c5 = c4 replace " to " with "-"
        var c6 = c5 replace "to" with "-"

        var detectedPayType =
            if (c6 contains "hour") "hourly"
            else if (c6 contains "week" or c6 contains "biweekly") "biweekly"
            else if (c6 contains "year" or c6 contains "annual" or c6 contains "annually") "annual"
            else ""

        var d1 = c6 replace "per hour" with ""
        var d2 = d1 replace "/hour" with ""
        var d3 = d2 replace "hour" with ""
        var d4 = d3 replace "per week" with ""
        var d5 = d4 replace "/week" with ""
        var d6 = d5 replace "week" with ""
        var d7 = d6 replace "biweekly" with ""
        var d8 = d7 replace "per year" with ""
        var d9 = d8 replace "/year" with ""
        var d10 = d9 replace "/ annually" with ""
        var d11 = d10 replace "annually" with ""
        var d12 = d11 replace "annual" with ""
        var d13 = d12 replace "year" with ""
        var cleaned = d13 replace " " with ""
        ---
        if (cleaned == "") 0
        else do {
            var parts = cleaned splitBy "-"
            var minVal = safeVal(parts[0])
            var maxVal = if (sizeOf(parts) > 1) safeVal(parts[1]) else minVal
            ---
            if (minVal <= 0 or maxVal <= 0) 0
            else do {
                var resolvedPayType =
                    if (detectedPayType != "") detectedPayType
                    else if (maxVal <= 300) "hourly"
                    else if (maxVal <= 10000) "biweekly"
                    else "annual"
                var result = if (sel == "min") convertToBiweekly(minVal, resolvedPayType)
                             else convertToBiweekly(maxVal, resolvedPayType)
                ---
                round(result)
            }
        }
    }
}
```
Notes/assumptions made porting this:
- **`safeVal` confirmed 2026-07-14** against the real VB `SafeVal` (4th screenshot): `On Error Resume Next` + `Val(valStr)` after trimming trailing `"."`/`" "` characters — VB's `Val()` does a **leading-numeric-prefix parse** (reads from the start, stops at the first invalid character, returns `0` if nothing valid at the start), not a strict whole-string match. The regex-scan port above (`^-?[0-9]+(?:\.[0-9]+)?`) matches this correctly; the original guess (strict `^...$` full-match) was wrong and has been corrected. The VB trailing-`.`/`" "`-trim loop is effectively subsumed by the leading-prefix regex (a lone trailing `.` with no following digit is never included in the match either way), so it wasn't ported as a separate step.
- VB's `CInt(...)` (rounds to nearest integer, banker's rounding on exact `.5`) ported as DataWeave's `round(...)` (rounds half away from zero) — behaviorally identical except on an exact `.5` tie, considered close enough not to block on.
- The VB source's `"/ annually"` replace has a literal space after the slash (`"/ annually"`, not `"/annually"`) — transcribed verbatim, not a typo I introduced.
- A companion `GetBusinessEntityType` VB function was also visible in the same screenshot (`I`→"Sole Proprietorship", `P`→"General Partnership", `C`→"Corporation For Profit") — confirms this is the same client helper library Jewelry's `businessEntityTypes` map in `transform2-account.dwl` was originally sourced from. Not relevant to BiWeeklyPayroll (its `Business_Entity_Type__c` is hardcoded `"Customer"`, already confirmed) — noted for context only, no action needed.

**Fix (2026-07-14) — `"Unable to resolve reference of: '$'"` error in Studio**: the `c1 replace "$" with ""` step (stripping a leading currency symbol) hit a parse error in Studio's Transform Message component. The repo's copy of the file has plain straight quotes, so this is most likely a copy-paste artifact (e.g. curly/smart quotes introduced when pasting from an email into Studio, making the parser see a bare `$` outside any string). Changed to a regex literal, `replace /\$/ with ""`, which sidesteps the ambiguity — regex literals are less prone to this class of paste issue and are the more idiomatic DataWeave way to match a special character like `$` regardless. **Not yet confirmed fixed in Studio** — verify after re-pasting this line.

**`normalizePaymentMethods` helper (confirmed 2026-07-14, ported from a client-provided VB script, `NormalizePaymentMethods` in a `Helpers` module)** — non-exclusive substring matching against `MethodPaid`, joined with `"; "` when multiple match, defaults to `"Other"` only when the input is non-blank but nothing matched (blank input stays blank, doesn't become `"Other"`):
```
fun normalizePaymentMethods(raw) = do {
    var inputStr = raw default ""
    var lowerStr = lower(inputStr)
    ---
    if (inputStr == "") ""
    else do {
        var parts = [
            if (lowerStr contains "check") "Check" else null,
            if (lowerStr contains "direct deposit") "Direct Deposit" else null,
            if (lowerStr contains "pay card" or lowerStr contains "paycard") "Pay Card" else null,
            if (lowerStr contains "other") "Other" else null
        ] filter (p) -> p != null
        ---
        if (isEmpty(parts)) "Other" else (parts joinBy "; ")
    }
}
```
Note: the VB source checks `"pay card"` and `"pay cards"` as two separate conditions, but `"pay card"` is always a substring of `"pay cards"`, so the second check is redundant — collapsed to a single `"pay card"` check (plus `"paycard"`, the no-space variant) with no behavior change.

**`normalizeDayValue` helper (confirmed 2026-07-14, ported from a second client-provided VB script, `NormalizeDayValue`)** — searches `PayDay` for any day-of-week name (singular or plural, e.g. "Friday"/"Fridays"), case-insensitive, returns the canonical capitalized day name of the **first** match in `Sunday..Saturday` order (matching the VB `For` loop's array order and early exit), or `""` if nothing matches:
```
fun normalizeDayValue(raw) = do {
    var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    var normalizedInput = lower(trim(raw default ""))
    var matches = days filter (day) -> (normalizedInput contains lower(day)) or (normalizedInput contains (lower(day) ++ "s"))
    ---
    if (isEmpty(matches)) "" else matches[0]
}
```

### Note object (confirmed 2026-07-12 — new, not present in Jewelry/Petroleum)
BiWeeklyPayroll loads a **Note** object instead of Invoice__c/InvoiceLine__c/Payment__c (which this unit doesn't touch at all, per the correction above). Field mapping/details not yet provided — user will supply after the rest of the flow (Account/Location/Address/Contact/BLA/BusinessLicense/Assessment/AQR) is designed.

**Update (2026-07-14)**: with the main BiWeeklyPayroll chain and `CleanupBiWeeklyPayroll` both confirmed working, Note is the last piece for this work unit. User is starting the Note design/build on **Petroleum** first, not BiWeeklyPayroll — **not yet confirmed whether this means Note is now in scope for Petroleum too** (a scope addition beyond what's documented in section 6, which never mentioned Note), or whether Petroleum is just being used as the build/prototype location before porting the design to BiWeeklyPayroll. Check which before assuming Petroleum's scope has changed.

### Building in Studio (started 2026-07-12) — from scratch, like Petroleum
Per lesson 7 in [[project_anypoint_salesforce_connectivity]], **do not** raw-copy `Petroleum.xml`/`Jewelry.xml` to start this flow — Studio treats copied flow files as linked. Build `BiWeeklyPayroll.xml` fresh in the Studio GUI instead.

**Trigger File — `LoadReadyFlagBiWeeklyPayroll.csv`**: own sentinel file, same convention as Jewelry/Petroleum (section 2/6) — `Min Size: 1`, created only after `BiWeeklyPayroll.csv` is fully in place in `C:\data\`.

**On New or Updated File Settings**: Directory `C:\data\`, File Name Pattern `LoadReadyFlagBiWeeklyPayroll.csv`, Min Size `1`, polling interval `10` seconds (same as Jewelry/Petroleum).

**Flow Structure so far**:
```
On New or Updated File (C:\data\, LoadReadyFlagBiWeeklyPayroll.csv)
  → File Read: C:\data\BiWeeklyPayroll.csv
  → Transform Message (transform-filter-and-name-biweeklypayroll.dwl — CSV → Java, header: true;
      returns {rows, logEntries})
  → Set Variable: filterResult = #[payload]
  → Set Variable: biWeeklyPayrollRows = #[vars.filterResult.rows]
  → Set Variable: logEntries = #[vars.filterResult.logEntries]   (first write — no `default []` needed
      here since this is the very first place logEntries is set, unlike every append after this)
  → Flow Reference: InitAccountRecordTypeBiWeeklyPayroll (runs once — sets vars.accountRecordTypeId)
  → For Each row: (Collection: #[vars.biWeeklyPayrollRows])
      → Set Variable: row = #[payload]
      → Flow Reference: AddAccount
          → Transform Message (transform-account-biweeklypayroll.dwl)
          → Salesforce Create Account (Records: #[[payload]]) → [Result & Log Pattern → logEntries,
              object: "Account", keyed by vars.row.RID instead of jobno/licenseno]
          → Set Variable: accountId = vars.accountResult.id
```

**`InitAccountRecordTypeBiWeeklyPayroll` sub-flow body** (same query as Petroleum's, see the Account field mapping section above):
```
Salesforce Query: SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account'
Set Variable: accountRecordTypeId = #[payload[0].Id]
```

**Confirmed working in Studio (2026-07-13)**: trigger → file read → filter transform → `InitAccountRecordTypeBiWeeklyPayroll` → `For Each` → `AddAccount` (Account create) tested successfully. `AddLocationsAndAddressesBiWeeklyPayroll` (Location → Address__c → PartyAddress__c) also confirmed working in Studio.

**Confirmed working in Studio (2026-07-14)**: `AddContactsBiWeeklyPayroll` (Contact create, 0-2 per row) tested successfully. `AddBusinessLicenseAppBiWeeklyPayroll` (BLA → BusinessLicense) also confirmed working. `InitAssessmentQuestionVersionBiWeeklyPayroll` → Assessment → all 13 AssessmentQuestionResponse questions now confirmed working end to end too, after resolving the `Name`-matching bugs above.

**Main per-row chain now fully confirmed working end to end**: Account → Account_Status__c (still deferred, see below) → Location → Address__c → PartyAddress__c → Contact → BLA → BusinessLicense → Assessment → AQR (all 13 questions).

**Not yet wired/resolved**: Account_Status__c nested inside `AddAccount` (deferred — its date-precedence logic isn't decided yet, see Open Questions), and the Note object (details still deferred by the user until everything else is done). These are the only two things left in this work unit.

### Cleanup: `CleanupBiWeeklyPayroll` sub-flow (confirmed working in Studio, 2026-07-14)
Following the same "separate named sub-flow" pattern just established for Petroleum's `CleanupPetroleum` (rather than inline steps at the tail of the main flow body) — called at the very end of the main flow, after the `For Each` completes:

1. **`import_log.csv`** — File Write (overwrite), content = `#[vars.logEntries as CSV]`. Column order: `RID, object, status, salesforce_id, error_code, error_message` (same shape as Jewelry's `jobno`-keyed and Petroleum's `licenseno`-keyed versions, just `RID`-keyed) — matches the `import_log` Postgres table minus `id`/`logged_at`, same interim reconciliation approach (pgAdmin Import/Export Data tool) documented in section 2.
2. **`bla_rid_map.csv`** — File Write (overwrite), content = `#[vars.blaRidLog as CSV]` — audit artifact mirroring Jewelry's `bla_jobno_map.csv`/Petroleum's `bla_license_map.csv`, naming matches the `blaRidLog` variable.
3. **Processed file archiving** — File Move `C:\data\BiWeeklyPayroll.csv` → `C:\data\processed\`, done **last** (after both writes above), same reasoning as Jewelry/Petroleum: if the flow errors out partway through, the source file is still in `C:\data\` for investigation/retry rather than already relocated. Only one file to move here (vs. Jewelry/Petroleum's two), since BiWeeklyPayroll has a single source file.

**TODO (cross-work-unit)**: Jewelry still doesn't have its own cleanup sub-flow either — retrofit it with a `CleanupJewelry` sub-flow (same pattern: `import_log.csv` write, `LaborStd.csv`/`LaborAR.csv` archiving) once Petroleum's and BiWeeklyPayroll's are both confirmed working, so all three work units follow the same convention.

**TODO (cross-work-unit, not yet implemented, 2026-07-16)**: flush `vars.logEntries` to a file on an unhandled exception, so a mid-run crash doesn't lose whatever log entries had already accumulated. Currently `import_log.csv` is only written once, at the very end, inside each work unit's Cleanup sub-flow (`CleanupPetroleum`/`CleanupBiWeeklyPayroll`, see above) — if the flow throws before reaching that point, everything in `vars.logEntries` up to the failure is lost, even though the Result & Log Pattern already captured it in memory. Proposed approach: add an **On Error Propagate** error handler at each main flow's top level (not per sub-flow — sub-flow errors already propagate up to the caller by default) containing a File Write of `#[vars.logEntries as CSV]` to a **distinct** filename (e.g. `import_log_error.csv`, not `import_log.csv`) so a partial error-path dump is never confused with, or overwritten by, a real completed run's log. On Error Propagate (not On Error Continue) keeps the flow actually failing/visible in Studio/Monitoring — this only adds a "dump what we have on the way out" step. Only helps for genuine unhandled exceptions (DataWeave coercion errors, lost connections, etc.) — the everyday per-record Salesforce validation failure already doesn't throw at all, which is why the Result & Log Pattern logs explicitly after every Create instead of relying on try/catch.

### Open questions
- All the "not yet mapped" items above — need per-field Salesforce mapping decisions before transforms can be written.
- Does Account_Status__c still apply the same way, and what's the precedence across `DateRecd/DateApproved/DateDenied/DateExpired/DateRevoked` for deriving status? Needs a real answer now that the file's grain is confirmed one-row-per-job.
- ~~Does BiWeeklyPayroll need the Sent Invoice cutover logic (`AddSentInvoice`, section 4)?~~ — moot, confirmed no Invoice/Payment loading at all for this unit.
- ~~Does BiWeeklyPayroll need its own `InitAccountRecordType` sub-flow (query-based, like Petroleum) or will it hardcode `RecordTypeId` like Jewelry currently does?~~ — resolved: query-based `InitAccountRecordTypeBiWeeklyPayroll`, confirmed working in Studio.

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

### Gotcha: `contains` binds looser than `or`/`and` — wrap each `contains` in explicit parens when chaining
`A contains B or C contains D` does **not** parse as `(A contains B) or (C contains D)` — `contains` has lower precedence than `or`, so it actually parses as `A contains (B or (C contains D))`, which tries to evaluate `B or (C contains D)` where `B` is a plain String, throwing `Cannot coerce String ('...') to Boolean` (the error points at the string literal, not the `contains` keyword, which is a bit misleading at first).

Fix — wrap every `contains` expression in its own parens before combining with `or`/`and`:
```
(A contains B) or (C contains D)
```
Found and fixed in `transform-assessment-question-response-biweeklypayroll.dwl` (2026-07-14) — `normalizePaymentMethods`'s `"pay card"`/`"paycard"` check and `getBiweeklySalary`'s pay-period keyword detection (`"week"`/`"biweekly"`, `"year"`/`"annual"`/`"annually"`) both hit this; `normalizeDayValue`'s day-matching `filter` was already written with the parens and didn't need fixing. Same category of DataWeave operator-precedence surprise as the `filter`/`map` gotcha above — worth checking for this pattern (`contains ... or/and ... contains`) in any future ported/translated logic, since it's easy to write unconsciously when porting from a language (like VB) where `Or`/`And` bind differently.

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
