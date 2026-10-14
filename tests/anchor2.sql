SET NOCOUNT ON;
SELECT COUNT(*) AS baris_peralatan_sejak_2025_05_01,
       AVG(f.efficiency_ratio) * 100 AS avg_efisiensi_pct,
       SUM(f.operating_hours) * 100.0 / NULLIF(SUM(f.operating_hours + f.downtime_hours), 0) AS rasio_jumlah_pct
FROM fact.FactEquipmentUsage f
JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE t.[date] >= '2025-05-01';
