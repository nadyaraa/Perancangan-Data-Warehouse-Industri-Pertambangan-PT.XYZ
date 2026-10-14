SET NOCOUNT ON;
PRINT '--- jumlah baris vs README';
SELECT 'DimTime' AS tabel, COUNT(*) AS n, 830 AS readme FROM dim.DimTime
UNION ALL SELECT 'DimSite', COUNT(*), 1747 FROM dim.DimSite
UNION ALL SELECT 'DimEquipment', COUNT(*), 6 FROM dim.DimEquipment
UNION ALL SELECT 'DimMaterial', COUNT(*), 5 FROM dim.DimMaterial
UNION ALL SELECT 'DimEmployee', COUNT(*), 10 FROM dim.DimEmployee
UNION ALL SELECT 'DimShift', COUNT(*), 3 FROM dim.DimShift
UNION ALL SELECT 'DimProject', COUNT(*), 50 FROM dim.DimProject
UNION ALL SELECT 'DimAccount', COUNT(*), 30 FROM dim.DimAccount
UNION ALL SELECT 'FactEquipmentUsage', COUNT(*), 236892 FROM fact.FactEquipmentUsage
UNION ALL SELECT 'FactProduction', COUNT(*), 2261 FROM fact.FactProduction
UNION ALL SELECT 'FactFinancialTransaction', COUNT(*), 115901 FROM fact.FactFinancialTransaction;

PRINT '--- varian efisiensi (target 95.66)';
SELECT 'semua_data_avg_ratio' AS varian, AVG(f.efficiency_ratio)*100 AS pct FROM fact.FactEquipmentUsage f
UNION ALL SELECT 'semua_data_rasio_jam',
  SUM(f.operating_hours)*100.0/NULLIF(SUM(f.operating_hours+f.downtime_hours),0) FROM fact.FactEquipmentUsage f
UNION ALL SELECT 'avg_per_baris_hitung_ulang',
  AVG(f.operating_hours/NULLIF(f.operating_hours+f.downtime_hours,0))*100 FROM fact.FactEquipmentUsage f
UNION ALL SELECT 'sejak_2025_05_01_per_baris_hitung_ulang',
  AVG(f.operating_hours/NULLIF(f.operating_hours+f.downtime_hours,0))*100
  FROM fact.FactEquipmentUsage f JOIN dim.DimTime t ON f.time_key=t.time_key WHERE t.[date]>='2025-05-01';

PRINT '--- efisiensi per tahun';
SELECT YEAR(t.[date]) AS tahun, COUNT(*) AS n, AVG(f.efficiency_ratio)*100 AS avg_pct
FROM fact.FactEquipmentUsage f JOIN dim.DimTime t ON f.time_key=t.time_key
GROUP BY YEAR(t.[date]) ORDER BY tahun;
