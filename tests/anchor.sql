SET NOCOUNT ON;
WITH m AS (
  SELECT t.[date] AS dt, mat.material_type, SUM(p.produced_volume) AS vol
  FROM fact.FactProduction p
  JOIN dim.DimMaterial mat ON p.material_key = mat.material_key
  JOIN dim.DimTime t ON p.time_key = t.time_key
  GROUP BY t.[date], mat.material_type
),
d AS (SELECT DISTINCT [date] AS dt FROM dim.DimTime)
SELECT TOP 6 x.tanggal_mulai, x.metal, x.ore,
       ABS(x.metal - 434721) + ABS(x.ore - 112687) AS selisih_total
FROM (
  SELECT d.dt AS tanggal_mulai,
    (SELECT SUM(vol) FROM m WHERE m.dt >= d.dt AND m.material_type = 'Metal') AS metal,
    (SELECT SUM(vol) FROM m WHERE m.dt >= d.dt AND m.material_type = 'Ore')   AS ore
  FROM d
) x
WHERE x.metal IS NOT NULL AND x.ore IS NOT NULL
ORDER BY selisih_total;
PRINT '--- rentang tanggal DimTime';
SELECT MIN([date]) AS tanggal_awal, MAX([date]) AS tanggal_akhir, CAST(GETDATE() AS date) AS hari_ini FROM dim.DimTime;
