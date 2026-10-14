SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @y INT = (SELECT TOP 1 t.year FROM fact.FactProduction f JOIN dim.DimTime t ON f.time_key = t.time_key GROUP BY t.year ORDER BY SUM(f.produced_volume) DESC);
DECLARE @r VARCHAR(50) = (SELECT TOP 1 s.region FROM fact.FactProduction f
    JOIN dim.DimTime t ON f.time_key = t.time_key JOIN dim.DimSite s ON f.site_key = s.site_key
    WHERE t.year = @y GROUP BY s.region ORDER BY SUM(f.produced_volume) DESC);
DECLARE @mt VARCHAR(50) = (SELECT TOP 1 m.material_type FROM fact.FactProduction f
    JOIN dim.DimTime t ON f.time_key = t.time_key JOIN dim.DimMaterial m ON f.material_key = m.material_key
    WHERE t.year = @y GROUP BY m.material_type ORDER BY SUM(f.produced_volume) DESC);

PRINT CONCAT('Parameter otomatis: tahun=', @y, ', region=', @r, ', material_type=', @mt);

PRINT '=== 1. SLICE: produksi tahun terpilih per material_type ===';
SELECT m.material_type, SUM(f.produced_volume) AS total_produksi, COUNT(*) AS jumlah_baris
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.year = @y
GROUP BY m.material_type
ORDER BY total_produksi DESC;

PRINT '=== 2. DICE: tahun + region + material_type terpilih, per kuartal dan material ===';
SELECT t.quarter, m.material_name, SUM(f.produced_volume) AS total_produksi, SUM(f.total_cost) AS total_biaya
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimSite s ON f.site_key = s.site_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.year = @y AND s.region = @r AND m.material_type = @mt
GROUP BY t.quarter, m.material_name
ORDER BY t.quarter, m.material_name;

PRINT '=== 3. ROLL-UP: tahun > kuartal > bulan (baris pertama = grand total) ===';
SELECT t.year, t.quarter, t.month,
       GROUPING_ID(t.year, t.quarter, t.month) AS level_agregasi,
       SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
GROUP BY ROLLUP (t.year, t.quarter, t.month)
ORDER BY t.year, t.quarter, t.month;

PRINT '=== 4a. DRILL-DOWN level 1: produksi per region (tahun terpilih) ===';
SELECT s.region, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimSite s ON f.site_key = s.site_key
WHERE t.year = @y
GROUP BY s.region ORDER BY total_produksi DESC;

PRINT '=== 4b. DRILL-DOWN level 2: site dalam region terpilih ===';
SELECT s.region, s.site_name, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimSite s ON f.site_key = s.site_key
WHERE t.year = @y AND s.region = @r
GROUP BY s.region, s.site_name ORDER BY total_produksi DESC;

PRINT '=== 4c. DRILL-DOWN level 3: material per site dalam region terpilih ===';
SELECT s.site_name, m.material_name, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimSite s ON f.site_key = s.site_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.year = @y AND s.region = @r
GROUP BY s.site_name, m.material_name
ORDER BY s.site_name, total_produksi DESC;

PRINT '=== 5. PIVOT (dinamis): produksi per bulan x material_name, tahun terpilih ===';
DECLARE @cols NVARCHAR(MAX) = STUFF((
    SELECT ',' + QUOTENAME(material_name)
    FROM (SELECT DISTINCT material_name FROM dim.DimMaterial) x
    ORDER BY material_name
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
DECLARE @sql NVARCHAR(MAX) = N'
SELECT pv.month, pv.month_name, ' + @cols + N'
FROM (SELECT t.month, t.month_name, m.material_name, f.produced_volume
      FROM fact.FactProduction f
      JOIN dim.DimTime t ON f.time_key = t.time_key
      JOIN dim.DimMaterial m ON f.material_key = m.material_key
      WHERE t.year = @y) src
PIVOT (SUM(produced_volume) FOR material_name IN (' + @cols + N')) pv
ORDER BY pv.month;';
EXEC sp_executesql @sql, N'@y INT', @y = @y;

PRINT '=== 6. DRILL-ACROSS tanpa fan-out: produksi, alat, keuangan per bulan ===';
DECLARE @y6 INT = (SELECT MAX(t.year) FROM dim.DimTime t
    WHERE EXISTS (SELECT 1 FROM fact.FactProduction f WHERE f.time_key = t.time_key)
      AND EXISTS (SELECT 1 FROM fact.FactEquipmentUsage f WHERE f.time_key = t.time_key)
      AND EXISTS (SELECT 1 FROM fact.FactFinancialTransaction f WHERE f.time_key = t.time_key));
PRINT CONCAT('Bagian 6 memakai tahun irisan ketiga fakta: ', @y6);
WITH p AS (
    SELECT t.month, SUM(f.produced_volume) AS produksi, SUM(f.total_cost) AS biaya_produksi
    FROM fact.FactProduction f JOIN dim.DimTime t ON f.time_key = t.time_key
    WHERE t.year = @y6 GROUP BY t.month),
e AS (
    SELECT t.month, SUM(f.operating_hours) AS jam_operasi, SUM(f.downtime_hours) AS jam_downtime,
           AVG(f.efficiency_ratio) AS rata_efisiensi
    FROM fact.FactEquipmentUsage f JOIN dim.DimTime t ON f.time_key = t.time_key
    WHERE t.year = @y6 GROUP BY t.month),
c AS (
    SELECT t.month, SUM(f.budgeted_cost) AS anggaran, SUM(f.actual_cost) AS realisasi
    FROM fact.FactFinancialTransaction f JOIN dim.DimTime t ON f.time_key = t.time_key
    WHERE t.year = @y6 GROUP BY t.month)
SELECT mo.month, p.produksi, p.biaya_produksi, e.jam_operasi, e.jam_downtime, e.rata_efisiensi, c.anggaran, c.realisasi
FROM (SELECT DISTINCT month FROM dim.DimTime WHERE year = @y6) mo
LEFT JOIN p ON p.month = mo.month
LEFT JOIN e ON e.month = mo.month
LEFT JOIN c ON c.month = mo.month
ORDER BY mo.month;

PRINT '=== 7. COVERAGE: cakupan data per tahun untuk tiga tabel fakta ===';
SELECT COALESCE(p.year, e.year, c.year) AS year,
       p.produksi, e.jam_operasi, c.realisasi_biaya
FROM (SELECT t.year, SUM(f.produced_volume) AS produksi
      FROM fact.FactProduction f JOIN dim.DimTime t ON f.time_key = t.time_key GROUP BY t.year) p
FULL JOIN (SELECT t.year, SUM(f.operating_hours) AS jam_operasi
      FROM fact.FactEquipmentUsage f JOIN dim.DimTime t ON f.time_key = t.time_key GROUP BY t.year) e
  ON e.year = p.year
FULL JOIN (SELECT t.year, SUM(f.actual_cost) AS realisasi_biaya
      FROM fact.FactFinancialTransaction f JOIN dim.DimTime t ON f.time_key = t.time_key GROUP BY t.year) c
  ON c.year = COALESCE(p.year, e.year)
ORDER BY 1;

PRINT '=== 8. PEMBANDING README: produksi per material_type, tahun >= 2025 (README: Metal 434.721, Ore 112.687) ===';
SELECT m.material_type, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.year >= 2025
GROUP BY m.material_type
ORDER BY m.material_type;

PRINT '=== SELF-TEST: grand total ROLLUP = total langsung ===';
DECLARE @langsung DECIMAL(18,2) = (SELECT SUM(produced_volume) FROM fact.FactProduction);
DECLARE @rollup DECIMAL(18,2) = (
    SELECT SUM(x.v) FROM (
        SELECT SUM(f.produced_volume) AS v
        FROM fact.FactProduction f JOIN dim.DimTime t ON f.time_key = t.time_key
        GROUP BY t.year) x);
SELECT CASE WHEN @langsung = @rollup THEN 'PASS' ELSE 'FAIL' END AS status,
       @langsung AS total_langsung, @rollup AS total_via_dimensi;
