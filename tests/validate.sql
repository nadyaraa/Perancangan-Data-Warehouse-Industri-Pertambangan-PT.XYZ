-- =====================================================================
-- tests/validate.sql  --  Validasi otomatis PT XYZ Data Warehouse
-- Jalankan : make validate
--   atau   : docker compose exec -T sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd \
--              -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -N -b -W \
--              -d PTXYZ_DataWarehouse -i /tests/validate.sql'
-- Status   : PASS = sesuai README | WARN = temuan/selisih terdokumentasi | FAIL = pelanggaran
-- Exit code != 0 hanya jika ada FAIL (opsi -b pada sqlcmd).
-- Bagian skema dihasilkan dari init-scripts/create-schema.sql.
-- =====================================================================
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#r') IS NOT NULL DROP TABLE #r;
CREATE TABLE #r (seq INT IDENTITY(1,1), kategori VARCHAR(20), uji VARCHAR(110), status VARCHAR(5), detail VARCHAR(250));

-- Batas tanggal yang menghasilkan angka agregat README (lihat RUNBOOK):
-- README memakai filter dashboard date >= DATEADD(day,-30,GETDATE()) yang dijalankan sekitar 2025-05-31.
DECLARE @anchor DATE = '2025-05-01';

-- ---------------------------------------------------------------- 1. SKEMA: tabel
;WITH e(tbl) AS (SELECT tbl FROM (VALUES
  ('dim.DimTime'),
  ('dim.DimSite'),
  ('dim.DimEquipment'),
  ('dim.DimMaterial'),
  ('dim.DimEmployee'),
  ('dim.DimShift'),
  ('dim.DimProject'),
  ('dim.DimAccount'),
  ('fact.FactEquipmentUsage'),
  ('fact.FactProduction'),
  ('fact.FactFinancialTransaction'),
  ('staging.EquipmentUsage'),
  ('staging.Production'),
  ('staging.FinancialTransaction')
) v(tbl))
INSERT #r (kategori, uji, status, detail)
SELECT 'Skema', 'Tabel ada: ' + e.tbl, CASE WHEN OBJECT_ID(e.tbl, 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END, ''
FROM e;

-- ---------------------------------------------------------------- 2. SKEMA: kolom & tipe (dim, fact)
CREATE TABLE #exp (tbl VARCHAR(60), col VARCHAR(60), tipe VARCHAR(30), computed BIT);
INSERT #exp (tbl, col, tipe, computed) VALUES
  ('dim.DimTime','time_key','int',0),
  ('dim.DimTime','time_id','int',0),
  ('dim.DimTime','date','date',0),
  ('dim.DimTime','day_of_month','int',0),
  ('dim.DimTime','day_name','varchar(20)',0),
  ('dim.DimTime','month','int',0),
  ('dim.DimTime','month_name','varchar(20)',0),
  ('dim.DimTime','quarter','int',0),
  ('dim.DimTime','year','int',0),
  ('dim.DimTime','is_weekend','bit',0),
  ('dim.DimTime','created_at','datetime2',0),
  ('dim.DimTime','created_by','varchar(50)',0),
  ('dim.DimSite','site_key','int',0),
  ('dim.DimSite','site_id','int',0),
  ('dim.DimSite','site_name','varchar(100)',0),
  ('dim.DimSite','region','varchar(50)',0),
  ('dim.DimSite','latitude','decimal(10,8)',0),
  ('dim.DimSite','longitude','decimal(11,8)',0),
  ('dim.DimSite','created_at','datetime2',0),
  ('dim.DimSite','created_by','varchar(50)',0),
  ('dim.DimEquipment','equipment_key','int',0),
  ('dim.DimEquipment','equipment_name','varchar(100)',0),
  ('dim.DimEquipment','equipment_type','varchar(50)',0),
  ('dim.DimEquipment','manufacture','varchar(50)',0),
  ('dim.DimEquipment','model','varchar(50)',0),
  ('dim.DimEquipment','capacity','decimal(10,2)',0),
  ('dim.DimEquipment','purchase_date','date',0),
  ('dim.DimEquipment','created_at','datetime2',0),
  ('dim.DimEquipment','created_by','varchar(50)',0),
  ('dim.DimMaterial','material_key','int',0),
  ('dim.DimMaterial','material_id','int',0),
  ('dim.DimMaterial','material_name','varchar(100)',0),
  ('dim.DimMaterial','material_type','varchar(50)',0),
  ('dim.DimMaterial','unit_of_measure','varchar(20)',0),
  ('dim.DimMaterial','created_at','datetime2',0),
  ('dim.DimMaterial','created_by','varchar(50)',0),
  ('dim.DimEmployee','employee_key','int',0),
  ('dim.DimEmployee','employee_id','int',0),
  ('dim.DimEmployee','employee_name','varchar(100)',0),
  ('dim.DimEmployee','position','varchar(50)',0),
  ('dim.DimEmployee','department','varchar(50)',0),
  ('dim.DimEmployee','status','varchar(20)',0),
  ('dim.DimEmployee','hire_date','date',0),
  ('dim.DimEmployee','created_at','datetime2',0),
  ('dim.DimEmployee','created_by','varchar(50)',0),
  ('dim.DimShift','shift_key','int',0),
  ('dim.DimShift','shift_id','int',0),
  ('dim.DimShift','shift_name','varchar(50)',0),
  ('dim.DimShift','start_time','time',0),
  ('dim.DimShift','end_time','time',0),
  ('dim.DimShift','created_at','datetime2',0),
  ('dim.DimShift','created_by','varchar(50)',0),
  ('dim.DimProject','project_key','int',0),
  ('dim.DimProject','project_id','int',0),
  ('dim.DimProject','project_name','varchar(100)',0),
  ('dim.DimProject','project_manager','varchar(100)',0),
  ('dim.DimProject','status','varchar(20)',0),
  ('dim.DimProject','start_date','date',0),
  ('dim.DimProject','end_date','date',0),
  ('dim.DimProject','created_at','datetime2',0),
  ('dim.DimProject','created_by','varchar(50)',0),
  ('dim.DimAccount','account_key','int',0),
  ('dim.DimAccount','account_id','int',0),
  ('dim.DimAccount','account_name','varchar(100)',0),
  ('dim.DimAccount','account_type','varchar(50)',0),
  ('dim.DimAccount','budget_category','varchar(50)',0),
  ('dim.DimAccount','created_at','datetime2',0),
  ('dim.DimAccount','created_by','varchar(50)',0),
  ('fact.FactEquipmentUsage','usage_key','int',0),
  ('fact.FactEquipmentUsage','equipment_usage_id','int',0),
  ('fact.FactEquipmentUsage','time_key','int',0),
  ('fact.FactEquipmentUsage','site_key','int',0),
  ('fact.FactEquipmentUsage','equipment_key','int',0),
  ('fact.FactEquipmentUsage','operating_hours','decimal(8,2)',0),
  ('fact.FactEquipmentUsage','downtime_hours','decimal(8,2)',0),
  ('fact.FactEquipmentUsage','fuel_consumption','decimal(10,2)',0),
  ('fact.FactEquipmentUsage','maintenance_cost','decimal(12,2)',0),
  ('fact.FactEquipmentUsage','efficiency_ratio','computed',1),
  ('fact.FactEquipmentUsage','created_at','datetime2',0),
  ('fact.FactEquipmentUsage','created_by','varchar(50)',0),
  ('fact.FactProduction','production_key','int',0),
  ('fact.FactProduction','production_id','int',0),
  ('fact.FactProduction','time_key','int',0),
  ('fact.FactProduction','site_key','int',0),
  ('fact.FactProduction','material_key','int',0),
  ('fact.FactProduction','employee_key','int',0),
  ('fact.FactProduction','shift_key','int',0),
  ('fact.FactProduction','produced_volume','decimal(12,2)',0),
  ('fact.FactProduction','unit_cost','decimal(10,2)',0),
  ('fact.FactProduction','total_cost','computed',1),
  ('fact.FactProduction','material_quantity','decimal(12,2)',0),
  ('fact.FactProduction','created_at','datetime2',0),
  ('fact.FactProduction','created_by','varchar(50)',0),
  ('fact.FactFinancialTransaction','transaction_key','int',0),
  ('fact.FactFinancialTransaction','transaction_id','int',0),
  ('fact.FactFinancialTransaction','time_key','int',0),
  ('fact.FactFinancialTransaction','site_key','int',0),
  ('fact.FactFinancialTransaction','project_key','int',0),
  ('fact.FactFinancialTransaction','account_key','int',0),
  ('fact.FactFinancialTransaction','budgeted_cost','decimal(12,2)',0),
  ('fact.FactFinancialTransaction','actual_cost','decimal(12,2)',0),
  ('fact.FactFinancialTransaction','variance_amount','computed',1),
  ('fact.FactFinancialTransaction','variance_percentage','computed',1),
  ('fact.FactFinancialTransaction','variance_status','varchar(20)',0),
  ('fact.FactFinancialTransaction','account_cost','decimal(12,2)',0),
  ('fact.FactFinancialTransaction','created_at','datetime2',0),
  ('fact.FactFinancialTransaction','created_by','varchar(50)',0);

SELECT s.name + '.' + t.name AS tbl, c.name AS col,
       CASE WHEN ty.name IN ('varchar','nvarchar','char','nchar')
              THEN ty.name + '(' + CASE WHEN c.max_length = -1 THEN 'max'
                   ELSE CAST(CASE WHEN ty.name IN ('nvarchar','nchar') THEN c.max_length / 2 ELSE c.max_length END AS VARCHAR(10)) END + ')'
            WHEN ty.name IN ('decimal','numeric')
              THEN ty.name + '(' + CAST(c.precision AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
            ELSE ty.name END AS tipe,
       c.is_computed AS computed
INTO #act
FROM sys.columns c
JOIN sys.tables t ON c.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE s.name IN ('dim', 'fact');

INSERT #r (kategori, uji, status, detail)
SELECT 'Skema', 'Kolom & tipe: ' + x.tbl, CASE WHEN x.bad = 0 THEN 'PASS' ELSE 'FAIL' END,
       CAST(x.bad AS VARCHAR(10)) + ' kolom tidak sesuai'
FROM (
  SELECT tb.tbl,
    (SELECT COUNT(*) FROM #exp e LEFT JOIN #act a ON a.tbl = e.tbl AND a.col = e.col
       WHERE e.tbl = tb.tbl AND (a.col IS NULL OR (e.computed = 0 AND a.tipe <> e.tipe) OR (e.computed = 1 AND a.computed = 0)))
  + (SELECT COUNT(*) FROM #act a LEFT JOIN #exp e ON a.tbl = e.tbl AND a.col = e.col
       WHERE a.tbl = tb.tbl AND e.col IS NULL) AS bad
  FROM (SELECT DISTINCT tbl FROM #exp) tb
) x;

-- ---------------------------------------------------------------- 3. JUMLAH BARIS (README: Star Schema Design)
SELECT 'dim.DimTime' AS tbl, COUNT(*) AS n INTO #cnt FROM dim.DimTime
UNION ALL SELECT 'dim.DimSite', COUNT(*) FROM dim.DimSite
UNION ALL SELECT 'dim.DimEquipment', COUNT(*) FROM dim.DimEquipment
UNION ALL SELECT 'dim.DimMaterial', COUNT(*) FROM dim.DimMaterial
UNION ALL SELECT 'dim.DimEmployee', COUNT(*) FROM dim.DimEmployee
UNION ALL SELECT 'dim.DimShift', COUNT(*) FROM dim.DimShift
UNION ALL SELECT 'dim.DimProject', COUNT(*) FROM dim.DimProject
UNION ALL SELECT 'dim.DimAccount', COUNT(*) FROM dim.DimAccount
UNION ALL SELECT 'fact.FactEquipmentUsage', COUNT(*) FROM fact.FactEquipmentUsage
UNION ALL SELECT 'fact.FactProduction', COUNT(*) FROM fact.FactProduction
UNION ALL SELECT 'fact.FactFinancialTransaction', COUNT(*) FROM fact.FactFinancialTransaction;

INSERT #r (kategori, uji, status, detail)
SELECT 'Jumlah baris', 'README: ' + w.tbl + ' = ' + CAST(w.n AS VARCHAR(12)),
       CASE WHEN c.n = w.n THEN 'PASS' ELSE 'FAIL' END, 'aktual = ' + CAST(c.n AS VARCHAR(12))
FROM (VALUES
  ('dim.DimTime', 830), ('dim.DimSite', 1747), ('dim.DimEquipment', 6), ('dim.DimMaterial', 5),
  ('dim.DimEmployee', 10), ('dim.DimShift', 3), ('dim.DimProject', 50), ('dim.DimAccount', 30),
  ('fact.FactEquipmentUsage', 236892), ('fact.FactProduction', 2261), ('fact.FactFinancialTransaction', 115901)
) w(tbl, n)
JOIN #cnt c ON c.tbl = w.tbl;

-- ---------------------------------------------------------------- 4. INTEGRITAS REFERENSIAL
INSERT #r (kategori, uji, status, detail)
SELECT 'Integritas', 'Jumlah FK constraint pada tabel fakta = 12',
       CASE WHEN x.n = 12 THEN 'PASS' ELSE 'FAIL' END, 'aktual = ' + CAST(x.n AS VARCHAR(10))
FROM (SELECT COUNT(*) AS n FROM sys.foreign_keys fk
      JOIN sys.tables t ON fk.parent_object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'fact') x;

SELECT 'fact.FactEquipmentUsage.time_key -> dim.DimTime.time_key' AS fk, COUNT(*) AS orphan INTO #orph FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key)
UNION ALL
SELECT 'fact.FactEquipmentUsage.site_key -> dim.DimSite.site_key' AS fk, COUNT(*) AS orphan FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key)
UNION ALL
SELECT 'fact.FactEquipmentUsage.equipment_key -> dim.DimEquipment.equipment_key' AS fk, COUNT(*) AS orphan FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimEquipment d WHERE d.equipment_key = f.equipment_key)
UNION ALL
SELECT 'fact.FactProduction.time_key -> dim.DimTime.time_key' AS fk, COUNT(*) AS orphan FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key)
UNION ALL
SELECT 'fact.FactProduction.site_key -> dim.DimSite.site_key' AS fk, COUNT(*) AS orphan FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key)
UNION ALL
SELECT 'fact.FactProduction.material_key -> dim.DimMaterial.material_key' AS fk, COUNT(*) AS orphan FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimMaterial d WHERE d.material_key = f.material_key)
UNION ALL
SELECT 'fact.FactProduction.employee_key -> dim.DimEmployee.employee_key' AS fk, COUNT(*) AS orphan FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimEmployee d WHERE d.employee_key = f.employee_key)
UNION ALL
SELECT 'fact.FactProduction.shift_key -> dim.DimShift.shift_key' AS fk, COUNT(*) AS orphan FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimShift d WHERE d.shift_key = f.shift_key)
UNION ALL
SELECT 'fact.FactFinancialTransaction.time_key -> dim.DimTime.time_key' AS fk, COUNT(*) AS orphan FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key)
UNION ALL
SELECT 'fact.FactFinancialTransaction.site_key -> dim.DimSite.site_key' AS fk, COUNT(*) AS orphan FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key)
UNION ALL
SELECT 'fact.FactFinancialTransaction.project_key -> dim.DimProject.project_key' AS fk, COUNT(*) AS orphan FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimProject d WHERE d.project_key = f.project_key)
UNION ALL
SELECT 'fact.FactFinancialTransaction.account_key -> dim.DimAccount.account_key' AS fk, COUNT(*) AS orphan FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimAccount d WHERE d.account_key = f.account_key);

INSERT #r (kategori, uji, status, detail)
SELECT 'Integritas', 'Orphan = 0: ' + fk, CASE WHEN orphan = 0 THEN 'PASS' ELSE 'FAIL' END, 'orphan = ' + CAST(orphan AS VARCHAR(12))
FROM #orph;

-- ---------------------------------------------------------------- 5. AGREGAT README
DECLARE @metal DECIMAL(18,2), @ore DECIMAL(18,2), @rows INT, @eff DECIMAL(10,4);
SELECT @metal = SUM(CASE WHEN m.material_type = 'Metal' THEN p.produced_volume END),
       @ore   = SUM(CASE WHEN m.material_type = 'Ore'   THEN p.produced_volume END)
FROM fact.FactProduction p
JOIN dim.DimMaterial m ON p.material_key = m.material_key
JOIN dim.DimTime t ON p.time_key = t.time_key
WHERE t.[date] >= @anchor;
SELECT @rows = COUNT(*), @eff = AVG(f.efficiency_ratio) * 100
FROM fact.FactEquipmentUsage f JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE t.[date] >= @anchor;

INSERT #r (kategori, uji, status, detail) VALUES
('Agregat', 'README: Produksi Metal = 434.721 (date >= anchor)', CASE WHEN @metal = 434721 THEN 'PASS' ELSE 'FAIL' END, 'aktual = ' + CAST(@metal AS VARCHAR(20))),
('Agregat', 'README: Produksi Ore = 112.687 (date >= anchor)',   CASE WHEN @ore = 112687 THEN 'PASS' ELSE 'FAIL' END,   'aktual = ' + CAST(@ore AS VARCHAR(20))),
('Agregat', 'README: baris peralatan 30 hari = 118.446 (date >= anchor)', CASE WHEN @rows = 118446 THEN 'PASS' ELSE 'FAIL' END, 'aktual = ' + CAST(@rows AS VARCHAR(12))),
('Agregat', 'README: efisiensi keseluruhan = 95,66%',
   CASE WHEN ABS(@eff - 95.66) < 0.005 THEN 'PASS' ELSE 'WARN' END,
   'aktual = ' + CAST(CAST(@eff AS DECIMAL(10,2)) AS VARCHAR(12)) + '; selisih = ' + CAST(CAST(ABS(@eff - 95.66) AS DECIMAL(10,2)) AS VARCHAR(12)) + ' poin (tidak ada rumus di repo yang menghasilkan 95,66)');

-- ---------------------------------------------------------------- 6. KUALITAS DATA: rentang nilai (CSV sumber: semua >= 0, tanpa NULL)
INSERT #r (kategori, uji, status, detail)
SELECT 'Rentang nilai', q.uji, CASE WHEN q.n = 0 THEN 'PASS' ELSE 'FAIL' END, 'baris melanggar = ' + CAST(q.n AS VARCHAR(12))
FROM (
  SELECT 'FactEquipmentUsage: jam operasi/downtime/BBM/biaya >= 0' AS uji, COUNT(*) AS n FROM fact.FactEquipmentUsage
    WHERE operating_hours < 0 OR downtime_hours < 0 OR fuel_consumption < 0 OR maintenance_cost < 0
        OR operating_hours IS NULL OR downtime_hours IS NULL
  UNION ALL SELECT 'FactEquipmentUsage: efficiency_ratio di [0,1]', COUNT(*) FROM fact.FactEquipmentUsage
    WHERE efficiency_ratio < 0 OR efficiency_ratio > 1
  UNION ALL SELECT 'FactProduction: volume/unit_cost/quantity >= 0', COUNT(*) FROM fact.FactProduction
    WHERE produced_volume < 0 OR unit_cost < 0 OR material_quantity < 0 OR produced_volume IS NULL
  UNION ALL SELECT 'FactFinancialTransaction: budget/actual/cost >= 0', COUNT(*) FROM fact.FactFinancialTransaction
    WHERE budgeted_cost < 0 OR actual_cost < 0 OR account_cost < 0 OR budgeted_cost IS NULL OR actual_cost IS NULL
) q;

-- ---------------------------------------------------------------- 7. KUALITAS DATA: duplikasi
-- Kunci bisnis dimensi harus unik (FAIL bila tidak).
INSERT #r (kategori, uji, status, detail)
SELECT 'Duplikasi', q.uji, CASE WHEN q.dup = 0 THEN 'PASS' ELSE 'FAIL' END, 'kelebihan baris = ' + CAST(q.dup AS VARCHAR(12))
FROM (
  SELECT 'DimEquipment: equipment_name unik' AS uji, COUNT(*) - COUNT(DISTINCT equipment_name) AS dup FROM dim.DimEquipment
  UNION ALL SELECT 'DimMaterial: material_id unik', COUNT(*) - COUNT(DISTINCT material_id) FROM dim.DimMaterial
  UNION ALL SELECT 'DimEmployee: employee_id unik', COUNT(*) - COUNT(DISTINCT employee_id) FROM dim.DimEmployee
  UNION ALL SELECT 'DimShift: shift_id unik', COUNT(*) - COUNT(DISTINCT shift_id) FROM dim.DimShift
  UNION ALL SELECT 'DimProject: project_id unik', COUNT(*) - COUNT(DISTINCT project_id) FROM dim.DimProject
  UNION ALL SELECT 'DimAccount: account_id unik', COUNT(*) - COUNT(DISTINCT account_id) FROM dim.DimAccount
) q;

-- Temuan pada logika ETL README (tidak diubah, hanya dilaporkan): grain tidak unik.
INSERT #r (kategori, uji, status, detail)
SELECT 'Temuan DQ', q.uji, CASE WHEN q.n = q.uniq THEN 'PASS' ELSE 'WARN' END,
       'baris = ' + CAST(q.n AS VARCHAR(12)) + '; kunci unik = ' + CAST(q.uniq AS VARCHAR(12)) +
       '; faktor = ' + CAST(CAST(1.0 * q.n / NULLIF(q.uniq, 0) AS DECIMAL(10,1)) AS VARCHAR(12)) + 'x'
FROM (
  SELECT 'DimSite: baris vs site_name unik' AS uji, COUNT(*) AS n, COUNT(DISTINCT site_name) AS uniq FROM dim.DimSite
  UNION ALL SELECT 'DimTime: baris vs time_id unik', COUNT(*), COUNT(DISTINCT time_id) FROM dim.DimTime
  UNION ALL SELECT 'FactEquipmentUsage: baris vs equipment_usage_id unik', COUNT(*), COUNT(DISTINCT equipment_usage_id) FROM fact.FactEquipmentUsage
  UNION ALL SELECT 'FactProduction: baris vs production_id unik', COUNT(*), COUNT(DISTINCT production_id) FROM fact.FactProduction
  UNION ALL SELECT 'FactFinancialTransaction: baris vs transaction_id unik', COUNT(*), COUNT(DISTINCT transaction_id) FROM fact.FactFinancialTransaction
) q;

INSERT #r (kategori, uji, status, detail)
SELECT 'Temuan DQ', 'FactFinancialTransaction.variance_status terisi (ETL tidak memuat kolom ini)',
       CASE WHEN x.kosong = 0 THEN 'PASS' ELSE 'WARN' END,
       'NULL = ' + CAST(x.kosong AS VARCHAR(12)) + ' dari ' + CAST(x.total AS VARCHAR(12)) + ' baris'
FROM (SELECT COUNT(*) AS total, SUM(CASE WHEN variance_status IS NULL THEN 1 ELSE 0 END) AS kosong FROM fact.FactFinancialTransaction) x;

-- ---------------------------------------------------------------- HASIL
SELECT seq, kategori, uji, status, detail FROM #r ORDER BY seq;

DECLARE @p INT = (SELECT COUNT(*) FROM #r WHERE status = 'PASS'),
        @w INT = (SELECT COUNT(*) FROM #r WHERE status = 'WARN'),
        @f INT = (SELECT COUNT(*) FROM #r WHERE status = 'FAIL');
PRINT '';
PRINT 'RINGKASAN: PASS=' + CAST(@p AS VARCHAR(10)) + '  WARN=' + CAST(@w AS VARCHAR(10)) + '  FAIL=' + CAST(@f AS VARCHAR(10));
IF @f > 0 RAISERROR('VALIDASI GAGAL: %d uji FAIL', 16, 1, @f);
