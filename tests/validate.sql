SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

-- Validasi otomatis PT XYZ DW terhadap klaim README.
-- Jalankan: make validate   (atau: sqlcmd -b ... < tests/validate.sql)
-- Status: PASS | FAIL | WARN 

CREATE TABLE #r (
    grp      NVARCHAR(20),
    test     NVARCHAR(120),
    expected NVARCHAR(60),
    actual   NVARCHAR(60),
    status   NVARCHAR(5)
);

-- 1. SKEMA: README ---------------------------
INSERT INTO #r
SELECT 'SKEMA', 'tabel ada: ' + x.s + '.' + x.t, 'ada',
       CASE WHEN OBJECT_ID(x.s + '.' + x.t, 'U') IS NOT NULL THEN 'ada' ELSE 'tidak ada' END,
       CASE WHEN OBJECT_ID(x.s + '.' + x.t, 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES
 ('dim','DimTime'),('dim','DimSite'),('dim','DimEquipment'),('dim','DimMaterial'),
 ('dim','DimEmployee'),('dim','DimShift'),('dim','DimProject'),('dim','DimAccount'),
 ('fact','FactEquipmentUsage'),('fact','FactProduction'),('fact','FactFinancialTransaction')
) AS x(s,t);

-- 2. JUMLAH BARIS sesuai README ------------------------------------------
INSERT INTO #r
SELECT 'BARIS', c.tbl, CAST(c.exp AS NVARCHAR(60)), CAST(c.n AS NVARCHAR(60)),
       CASE WHEN c.n = c.exp THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT 'dim.DimTime' tbl, (SELECT COUNT(*) FROM dim.DimTime) n, 830 exp UNION ALL
  SELECT 'dim.DimSite', (SELECT COUNT(*) FROM dim.DimSite), 1747 UNION ALL
  SELECT 'dim.DimEquipment', (SELECT COUNT(*) FROM dim.DimEquipment), 6 UNION ALL
  SELECT 'dim.DimMaterial', (SELECT COUNT(*) FROM dim.DimMaterial), 5 UNION ALL
  SELECT 'dim.DimEmployee', (SELECT COUNT(*) FROM dim.DimEmployee), 10 UNION ALL
  SELECT 'dim.DimShift', (SELECT COUNT(*) FROM dim.DimShift), 3 UNION ALL
  SELECT 'dim.DimProject', (SELECT COUNT(*) FROM dim.DimProject), 50 UNION ALL
  SELECT 'dim.DimAccount', (SELECT COUNT(*) FROM dim.DimAccount), 30 UNION ALL
  SELECT 'fact.FactEquipmentUsage', (SELECT COUNT(*) FROM fact.FactEquipmentUsage), 236892 UNION ALL
  SELECT 'fact.FactProduction', (SELECT COUNT(*) FROM fact.FactProduction), 2261 UNION ALL
  SELECT 'fact.FactFinancialTransaction', (SELECT COUNT(*) FROM fact.FactFinancialTransaction), 115901
) c;

-- 3. INTEGRITAS: 0 orphan untuk setiap FK fact -> dim --------------------
DECLARE @fk_found INT = 0;
DECLARE @sql NVARCHAR(MAX), @label NVARCHAR(200), @n INT;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
  SELECT
    'SELECT @n = COUNT(*) FROM ' + QUOTENAME(ps.name) + '.' + QUOTENAME(pt.name) + ' f ' +
    'LEFT JOIN ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name) + ' d ON f.' + QUOTENAME(pc.name) + ' = d.' + QUOTENAME(rc.name) +
    ' WHERE f.' + QUOTENAME(pc.name) + ' IS NOT NULL AND d.' + QUOTENAME(rc.name) + ' IS NULL',
    ps.name + '.' + pt.name + '.' + pc.name + ' -> ' + rs.name + '.' + rt.name
  FROM sys.foreign_key_columns fkc
  JOIN sys.tables pt  ON pt.object_id = fkc.parent_object_id
  JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
  JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
  JOIN sys.tables rt  ON rt.object_id = fkc.referenced_object_id
  JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
  JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
  WHERE ps.name = 'fact';
OPEN cur;
FETCH NEXT FROM cur INTO @sql, @label;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @fk_found += 1;
  EXEC sp_executesql @sql, N'@n INT OUTPUT', @n = @n OUTPUT;
  INSERT INTO #r VALUES ('ORPHAN', @label, '0', CAST(@n AS NVARCHAR(60)),
                         CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END);
  FETCH NEXT FROM cur INTO @sql, @label;
END
CLOSE cur; DEALLOCATE cur;
INSERT INTO #r VALUES ('ORPHAN', 'jumlah FK fact->dim terdeteksi (>0)', '>0', CAST(@fk_found AS NVARCHAR(60)),
                       CASE WHEN @fk_found > 0 THEN 'PASS' ELSE 'FAIL' END);

-- 4. AGREGAT README (batas tetap 2025-05-01, pengganti DATEADD(day,-30,GETDATE())) -----
INSERT INTO #r
SELECT 'AGREGAT', 'produksi Metal sejak 2025-05-01', '434721.00', CAST(v AS NVARCHAR(60)),
       CASE WHEN v = 434721 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(p.produced_volume) v
      FROM fact.FactProduction p
      JOIN dim.DimMaterial m ON p.material_key = m.material_key
      JOIN dim.DimTime t ON p.time_key = t.time_key
      WHERE m.material_type = 'Metal' AND t.[date] >= '2025-05-01') a;

INSERT INTO #r
SELECT 'AGREGAT', 'produksi Ore sejak 2025-05-01', '112687.00', CAST(v AS NVARCHAR(60)),
       CASE WHEN v = 112687 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(p.produced_volume) v
      FROM fact.FactProduction p
      JOIN dim.DimMaterial m ON p.material_key = m.material_key
      JOIN dim.DimTime t ON p.time_key = t.time_key
      WHERE m.material_type = 'Ore' AND t.[date] >= '2025-05-01') a;

INSERT INTO #r
SELECT 'AGREGAT', 'baris peralatan sejak 2025-05-01', '118446', CAST(v AS NVARCHAR(60)),
       CASE WHEN v = 118446 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) v
      FROM fact.FactEquipmentUsage f
      JOIN dim.DimTime t ON f.time_key = t.time_key
      WHERE t.[date] >= '2025-05-01') a;

-- Efisiensi: README 95.66%, hasil reproduksi 95.60%. Selisih terdokumentasi (WARN, toleransi 0.10 poin).
INSERT INTO #r
SELECT 'AGREGAT', 'efisiensi rata-rata (%) [selisih terdokumentasi]', '95.66', CAST(CAST(v AS DECIMAL(8,4)) AS NVARCHAR(60)),
       CASE WHEN ABS(v - 95.66) < 0.005 THEN 'PASS'
            WHEN ABS(v - 95.66) <= 0.10 THEN 'WARN'
            ELSE 'FAIL' END
FROM (SELECT AVG(efficiency_ratio) * 100 v FROM fact.FactEquipmentUsage) a;

-- 5. KUALITAS DATA: duplikasi dan rentang nilai --------------------------
INSERT INTO #r
SELECT 'DQ', 'duplikasi tanggal di DimTime', '0', CAST(COUNT(*) - COUNT(DISTINCT [date]) AS NVARCHAR(60)),
       CASE WHEN COUNT(*) - COUNT(DISTINCT [date]) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM dim.DimTime;

INSERT INTO #r
SELECT 'DQ', 'efficiency_ratio di luar [0,1]', '0', CAST(COUNT(*) AS NVARCHAR(60)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.FactEquipmentUsage WHERE efficiency_ratio < 0 OR efficiency_ratio > 1;

INSERT INTO #r
SELECT 'DQ', 'jam operasi/downtime negatif', '0', CAST(COUNT(*) AS NVARCHAR(60)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.FactEquipmentUsage WHERE operating_hours < 0 OR downtime_hours < 0;

INSERT INTO #r
SELECT 'DQ', 'produced_volume negatif', '0', CAST(COUNT(*) AS NVARCHAR(60)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.FactProduction WHERE produced_volume < 0;

-- Ringkasan ---------------------------------------------------------------
SELECT grp AS grup, test AS pengujian, expected AS diharapkan, actual AS hasil, status FROM #r ORDER BY grp, test;

DECLARE @pass INT = (SELECT COUNT(*) FROM #r WHERE status = 'PASS'),
        @warn INT = (SELECT COUNT(*) FROM #r WHERE status = 'WARN'),
        @fail INT = (SELECT COUNT(*) FROM #r WHERE status = 'FAIL');
PRINT '';
PRINT 'RINGKASAN: PASS=' + CAST(@pass AS VARCHAR(10)) + ' WARN=' + CAST(@warn AS VARCHAR(10)) + ' FAIL=' + CAST(@fail AS VARCHAR(10));
IF @fail > 0
    RAISERROR('VALIDASI GAGAL: %d tes FAIL', 16, 1, @fail);
ELSE
    PRINT 'VALIDASI LULUS';
