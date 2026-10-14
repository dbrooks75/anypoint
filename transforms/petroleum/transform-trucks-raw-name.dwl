%dw 2.0
input payload application/csv separator="|", quoteChar="\u0000"
output application/java

// Reused for both trucks_reg.unl (Current) and hitrucks.unl (Historical) — identical column
// shape/naming for both (confirmed 2026-08-06; the reg_plate_numb/date_tested naming difference
// only applies to the already-Excel-processed TrucksHis01/02 CSVs, not this raw .unl source).
// No SourceFileType column needed here — unlike LaborStd/MercStd, TrucksReg01/02 and TrucksHis01/02
// carry no SourceFileType field at all; Current vs Historical is distinguished by which file was
// read, not by a column value (see section 6's Vehicles source file layout).
var allCols = [
    "licenseno", "inspect_comp_code", "inspect_comp", "truck_make1", "year1", "reg_truck_numb1", "equipment_no1",
    "tested_sealed1", "truck_make2", "year2", "reg_truck_numb2", "equipment_no2", "tested_sealed2", "truck_make3",
    "year3", "reg_truck_numb3", "equipment_no3", "tested_sealed3", "truck_make4", "year4", "reg_truck_numb4",
    "equipment_no4", "tested_sealed4", "truck_make5", "year5", "reg_truck_numb5", "equipment_no5",
    "tested_sealed5", "truck_make6", "year6", "reg_truck_numb6", "equipment_no6", "tested_sealed6", "truck_make7",
    "year7", "reg_truck_numb7", "equipment_no7", "tested_sealed7", "truck_make8", "year8", "reg_truck_numb8",
    "equipment_no8", "tested_sealed8", "truck_make9", "year9", "reg_truck_numb9", "equipment_no9",
    "tested_sealed9", "truck_make10", "year10", "reg_truck_numb10", "equipment_no10", "tested_sealed10",
    "truck_make11", "year11", "reg_truck_numb11", "equipment_no11", "tested_sealed11", "truck_make12", "year12",
    "reg_truck_numb12", "equipment_no12", "tested_sealed12", "truck_make13", "year13", "reg_truck_numb13",
    "equipment_no13", "tested_sealed13", "truck_make14", "year14", "reg_truck_numb14", "equipment_no14",
    "tested_sealed14", "truck_make15", "year15", "reg_truck_numb15", "equipment_no15", "tested_sealed15",
    "truck_make16", "year16", "reg_truck_numb16", "equipment_no16", "tested_sealed16", "truck_make17", "year17",
    "reg_truck_numb17", "equipment_no17", "tested_sealed17", "truck_make18", "year18", "reg_truck_numb18",
    "equipment_no18", "tested_sealed18", "truck_make19", "year19", "reg_truck_numb19", "equipment_no19",
    "tested_sealed19", "truck_make20", "year20", "reg_truck_numb20", "equipment_no20", "tested_sealed20",
    "truck_make21", "year21", "reg_truck_numb21", "equipment_no21", "tested_sealed21", "truck_make22", "year22",
    "reg_truck_numb22", "equipment_no22", "tested_sealed22", "truck_make23", "year23", "reg_truck_numb23",
    "equipment_no23", "tested_sealed23", "truck_make24", "year24", "reg_truck_numb24", "equipment_no24",
    "tested_sealed24", "truck_make25", "year25", "reg_truck_numb25", "equipment_no25", "tested_sealed25",
    "truck_make26", "year26", "reg_truck_numb26", "equipment_no26", "tested_sealed26", "truck_make27", "year27",
    "reg_truck_numb27", "equipment_no27", "tested_sealed27", "truck_make28", "year28", "reg_truck_numb28",
    "equipment_no28", "tested_sealed28", "truck_make29", "year29", "reg_truck_numb29", "equipment_no29",
    "tested_sealed29", "truck_make30", "year30", "reg_truck_numb30", "equipment_no30", "tested_sealed30",
    "truck_make31", "year31", "reg_truck_numb31", "equipment_no31", "tested_sealed31", "truck_make32", "year32",
    "reg_truck_numb32", "equipment_no32", "tested_sealed32", "truck_make33", "year33", "reg_truck_numb33",
    "equipment_no33", "tested_sealed33", "truck_make34", "year34", "reg_truck_numb34", "equipment_no34",
    "tested_sealed34", "truck_make35", "year35", "reg_truck_numb35", "equipment_no35", "tested_sealed35",
    "truck_make36", "year36", "reg_truck_numb36", "equipment_no36", "tested_sealed36", "truck_make37", "year37",
    "reg_truck_numb37", "equipment_no37", "tested_sealed37", "truck_make38", "year38", "reg_truck_numb38",
    "equipment_no38", "tested_sealed38", "truck_make39", "year39", "reg_truck_numb39", "equipment_no39",
    "tested_sealed39", "truck_make40", "year40", "reg_truck_numb40", "equipment_no40", "tested_sealed40",
    "truck_make41", "year41", "reg_truck_numb41", "equipment_no41", "tested_sealed41", "truck_make42", "year42",
    "reg_truck_numb42", "equipment_no42", "tested_sealed42", "truck_make43", "year43", "reg_truck_numb43",
    "equipment_no43", "tested_sealed43", "truck_make44", "year44", "reg_truck_numb44", "equipment_no44",
    "tested_sealed44", "truck_make45", "year45", "reg_truck_numb45", "equipment_no45", "tested_sealed45",
    "truck_make46", "year46", "reg_truck_numb46", "equipment_no46", "tested_sealed46", "truck_make47", "year47",
    "reg_truck_numb47", "equipment_no47", "tested_sealed47", "truck_make48", "year48", "reg_truck_numb48",
    "equipment_no48", "tested_sealed48", "truck_make49", "year49", "reg_truck_numb49", "equipment_no49",
    "tested_sealed49", "truck_make50", "year50", "reg_truck_numb50", "equipment_no50", "tested_sealed50",
    "truck_make51", "year51", "reg_truck_numb51", "equipment_no51", "tested_sealed51", "truck_make52", "year52",
    "reg_truck_numb52", "equipment_no52", "tested_sealed52", "truck_make53", "year53", "reg_truck_numb53",
    "equipment_no53", "tested_sealed53", "truck_make54", "year54", "reg_truck_numb54", "equipment_no54",
    "tested_sealed54", "truck_make55", "year55", "reg_truck_numb55", "equipment_no55", "tested_sealed55",
    "truck_make56", "year56", "reg_truck_numb56", "equipment_no56", "tested_sealed56", "tot_reg_trucks", "batch_id"
]

fun stripDecimal(v) = (v default "" splitBy ".")[0]

var stripFields = ["licenseno"]

fun needsStrip(k: String) = (stripFields contains k) or (k matches /^year\d+$/)
---
payload map (row) -> do {
    // trim every field (leading/trailing whitespace) before any further processing — added
    // 2026-08-17, applies uniformly to all 285 columns since it runs before the column-name
    // mapping below
    var values = (row pluck $) map ((v) -> trim(v default ""))
    ---
    (allCols map ((c, idx) -> { (c): values[idx] }) reduce ((item, acc = {}) -> acc ++ item))
        mapObject ((value, key) -> do {
            var k = key as String
            ---
            if (needsStrip(k))
                { (key): stripDecimal(value) }
            else
                { (key): value }
        })
}
